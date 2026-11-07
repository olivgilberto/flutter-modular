import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tasks_module/adapters/driven/models/task_model.dart';
import 'package:tasks_module/adapters/driven/services/sqlite_task_service.dart';
import 'package:tasks_module/adapters/driven/services/tasks_database_schema.dart';
import 'package:tasks_module/adapters/driven/sync/task_syncable_outbox.dart';
import 'package:tasks_module/adapters/driven/task_api_paths.dart';
import 'package:tasks_module/domain/entities/task.dart';
import 'package:tasks_module/domain/value_objects/task_title.dart';

import '../../fakes.dart';
import '../../support/ffi_local_database.dart';

final class _MockApiClient extends Mock implements ApiClient {}

Task _task(String id, String title, {TaskStatus status = TaskStatus.open}) =>
    Task(
      id: id,
      title: TaskTitle.parse(title),
      createdAt: DateTime.utc(2026, 10, 27, 9),
      status: status,
    );

TaskModel _remote(String id, String title, {required int version}) => TaskModel(
  id: id,
  title: title,
  status: 'open',
  createdAt: DateTime.utc(2026, 10, 27, 9).millisecondsSinceEpoch,
  version: version,
);

/// Uma recusa do backend, como o adaptador HTTP a entrega.
ApiError _rejected(int status, [Object? body]) =>
    ApiError(ApiErrorKind.rejected, statusCode: status, body: body);

void main() {
  final now = DateTime.utc(2026, 10, 27, 12);
  late FfiLocalDatabaseFactory factory;
  late SqliteTaskService local;
  late _MockApiClient api;
  late FakeLogger logger;
  late TaskSyncableOutbox outbox;
  late int nextOperation;

  /// O que o backend recebeu, na ordem: método, caminho, corpo e chave.
  /// Listas, e não records, para que o `expect` compare os corpos por
  /// conteúdo.
  late List<List<Object?>> sent;

  /// A resposta de cada tarefa; sem entrada, aceita com a versão seguinte.
  late Map<String, Object> answers;

  setUp(() {
    nextOperation = 0;
    factory = FfiLocalDatabaseFactory();
    local = SqliteTaskService(
      databaseFactory: factory,
      newOperationId: () => 'op-${++nextOperation}',
      now: () => now,
    );
    api = _MockApiClient();
    logger = FakeLogger();
    outbox = TaskSyncableOutbox(
      apiClient: api,
      queue: local,
      conflicts: local,
      logger: logger,
    );
    sent = [];
    answers = {};
    var version = 10;
    Future<Object?> answer(String method, Invocation invocation) async {
      final path = invocation.positionalArguments.single as String;
      sent.add([
        method,
        path,
        invocation.namedArguments[#body],
        invocation.namedArguments[#idempotencyKey],
      ]);
      final reply = answers[path];
      if (reply is ApiError) throw reply;
      return reply ?? {'version': ++version};
    }

    when(
      () => api.put(
        any(),
        body: any(named: 'body'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((invocation) => answer('PUT', invocation));
    when(
      () => api.patch(
        any(),
        body: any(named: 'body'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((invocation) => answer('PATCH', invocation));
  });

  tearDown(() async {
    await local.dispose();
    await factory.close();
  });

  Future<List<String>> queued() async => [
    for (final op in await local.pendingInOrder()) op.id,
  ];

  test('envia em ordem, com o id da operação no corpo e no cabeçalho, e a '
      'alteração seguinte se apoia na versão que a criação recebeu', () async {
    await local.saveTask(_task('t-1', 'Comprar pão'));
    await local.saveTask(_task('t-1', 'Comprar pão integral'));
    await local.archiveTask('t-1');

    expect(await outbox.sync(), isFalse);

    final path = TaskApiPaths.task('t-1');
    expect(sent, [
      [
        'PUT',
        path,
        {
          'title': 'Comprar pão',
          'status': 'open',
          'createdAt': '2026-10-27T09:00:00.000Z',
          'operationId': 'op-1',
        },
        'op-1',
      ],
      [
        'PATCH',
        path,
        {
          'title': 'Comprar pão integral',
          'status': 'open',
          'operationId': 'op-2',
          'baseVersion': 11,
        },
        'op-2',
      ],
      [
        'PATCH',
        path,
        {'status': 'archived', 'operationId': 'op-3', 'baseVersion': 12},
        'op-3',
      ],
    ]);
    expect(await queued(), isEmpty);
    expect(await outbox.pendingCount(), 0);
  });

  for (final (label, error) in [
    ('sem conexão', const ApiError(ApiErrorKind.unreachable)),
    ('5xx', const ApiError(ApiErrorKind.server, statusCode: 503)),
    ('resposta ilegível', const ApiError(ApiErrorKind.invalidResponse)),
    ('401', _rejected(401)),
    ('429', _rejected(429)),
    ('409 que não é de versão', _rejected(409, {'code': 'request_in_flight'})),
  ]) {
    test(
      '$label: a operação fica, a rodada para e a ordem se mantém',
      () async {
        await local.saveTask(_task('t-1', 'Comprar pão'));
        await local.saveTask(_task('t-2', 'Pagar a luz'));
        answers[TaskApiPaths.task('t-1')] = error;

        expect(await outbox.sync(), isTrue);

        expect(sent, hasLength(1));
        expect(await queued(), ['op-1', 'op-2']);
        expect(await local.openConflictCount(), 0);
      },
    );
  }

  test('409 de versão vai para sync_conflicts, as operações seguintes da '
      'tarefa esperam, e as outras tarefas seguem', () async {
    await local.saveActiveTasks([
      _remote('t-1', 'Comprar pão', version: 3),
    ], refreshedAt: now);
    await local.saveTask(_task('t-1', 'Comprar pão', status: TaskStatus.done));
    await local.saveTask(_task('t-2', 'Pagar a luz'));
    await local.archiveTask('t-1');
    answers[TaskApiPaths.task('t-1')] = _rejected(409, {
      'code': 'version_conflict',
    });

    expect(await outbox.sync(), isFalse);

    expect([for (final s in sent) s[3]], ['op-1', 'op-2']);
    expect(await queued(), ['op-3']);
    expect(await local.entitiesWithOpenConflict(), {'t-1'});
    // A recusa e a operação que espera: nenhuma foi aceita.
    expect(await outbox.pendingCount(), 2);

    // A próxima rodada também não envia o que espera a decisão.
    sent.clear();
    expect(await outbox.sync(), isFalse);
    expect(sent, isEmpty);
  });

  test(
    'outra recusa 4xx também vai para sync_conflicts, como recusa',
    () async {
      await local.saveTask(_task('t-1', 'Comprar pão'));
      answers[TaskApiPaths.task('t-1')] = _rejected(422, {'code': 'invalid'});

      expect(await outbox.sync(), isFalse);

      final db = await factory.rawDatabase(tasksDatabaseSchema);
      final conflict = (await db.rawQuery(
        'SELECT * FROM sync_conflicts',
      )).single;
      expect(conflict['kind'], 'rejected');
      expect(conflict['status_code'], 422);
      expect(await queued(), isEmpty);
    },
  );

  test('404 num arquivamento sai da fila; numa alteração, é recusa', () async {
    await local.saveActiveTasks([
      _remote('t-1', 'Comprar pão', version: 3),
      _remote('t-2', 'Pagar a luz', version: 3),
    ], refreshedAt: now);
    await local.archiveTask('t-1');
    await local.saveTask(_task('t-2', 'Pagar a luz', status: TaskStatus.done));
    answers[TaskApiPaths.task('t-1')] = _rejected(404);
    answers[TaskApiPaths.task('t-2')] = _rejected(404);

    expect(await outbox.sync(), isFalse);

    expect(await queued(), isEmpty);
    expect(await local.entitiesWithOpenConflict(), {'t-2'});
  });

  test('uma resposta de sucesso sem a versão tira a operação da fila e vai '
      'para o registro de falhas', () async {
    await local.saveTask(_task('t-1', 'Comprar pão'));
    answers[TaskApiPaths.task('t-1')] = {'id': 't-1'};

    expect(await outbox.sync(), isFalse);

    expect(await queued(), isEmpty);
    expect(logger.errors, ['tasks outbox response']);
  });

  test('chamadas simultâneas compartilham o mesmo envio', () async {
    await local.saveTask(_task('t-1', 'Comprar pão'));
    final release = Completer<void>();
    when(
      () => api.put(
        any(),
        body: any(named: 'body'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async {
      await release.future;
      return {'version': 1};
    });

    final first = outbox.sync();
    final second = outbox.sync();
    release.complete();

    expect(await Future.wait([first, second]), [false, false]);
    verify(
      () => api.put(
        any(),
        body: any(named: 'body'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).called(1);
  });

  test('o nome nos logs é estável', () {
    expect(outbox.name, 'tasks');
  });
}
