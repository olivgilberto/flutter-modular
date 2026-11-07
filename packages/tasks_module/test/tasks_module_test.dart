import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tasks_module/adapters/driven/task_api_paths.dart';
import 'package:tasks_module/adapters/driving/bloc/task_conflicts_bloc.dart';
import 'package:tasks_module/adapters/driving/bloc/task_edit_bloc.dart';
import 'package:tasks_module/adapters/driving/bloc/task_list_bloc.dart';
import 'package:tasks_module/application/use_cases/task_use_case.dart';
import 'package:tasks_module/domain/entities/task.dart';
import 'package:tasks_module/domain/entities/task_conflict.dart';
import 'package:tasks_module/tasks_module.dart';

import 'fakes.dart';
import 'support/ffi_local_database.dart';

final class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late GetIt getIt;
  late _MockApiClient api;
  late DefaultLogoutCleanerRegistry cleaners;
  late DefaultOutboxRegistry outboxes;
  late FfiLocalDatabaseFactory databases;

  setUpAll(() => registerFallbackValue(<String, String>{}));

  // O escopo base como o host o monta, só com as portas que o módulo usa; o
  // módulo entra no escopo da sessão, como no openSessionScope do host.
  setUp(() {
    api = _MockApiClient();
    cleaners = DefaultLogoutCleanerRegistry();
    outboxes = DefaultOutboxRegistry();
    databases = FfiLocalDatabaseFactory();
    getIt = GetIt.asNewInstance()
      ..registerSingleton<ApiClient>(api)
      ..registerSingleton<LocalDatabaseFactory>(databases)
      ..registerSingleton<LogoutCleanerRegistry>(cleaners)
      ..registerSingleton<OutboxRegistry>(outboxes)
      ..registerSingleton<AppLogger>(FakeLogger())
      ..registerSingleton<AppAnalytics>(FakeAnalytics())
      ..pushNewScope(
        scopeName: 'session',
        init: (scope) => registerTasksModuleDependencies(scope),
      );
  });
  tearDown(() async {
    await getIt.reset();
    await databases.close();
  });

  /// Sem rede para enviar: o que o usuário faz fica na fila.
  void sendingFails() => when(
    () => api.put(
      any(),
      body: any(named: 'body'),
      idempotencyKey: any(named: 'idempotencyKey'),
    ),
  ).thenThrow(const ApiError(ApiErrorKind.unreachable));

  /// O backend devolve sempre a mesma lista, numa página só.
  void backendHas(List<Map<String, Object?>> items) => when(
    () => api.get(TaskApiPaths.tasks, query: any(named: 'query')),
  ).thenAnswer((_) async => {'items': items, 'nextCursor': null});

  test('a primeira lista vem do backend e, depois, do banco do '
      'módulo', () async {
    backendHas([
      {
        'id': 't-1',
        'title': 'Pagar a luz',
        'status': 'open',
        'createdAt': '2026-10-27T09:00:00.000Z',
        'version': 2,
      },
    ]);
    final tasks = getIt<TaskUseCase>();
    expect(getIt<TaskUseCase>(), same(tasks));

    final listed = await tasks.watchActiveTasks().first;
    expect(listed.single.title.value, 'Pagar a luz');

    // Já carregada uma vez, a lista vem do aparelho, sem outra ida à rede.
    await tasks.watchActiveTasks().first;
    verify(
      () => api.get(TaskApiPaths.tasks, query: any(named: 'query')),
    ).called(1);
  });

  test('uma tarefa criada no aparelho sobrevive à atualização, mesmo sem '
      'estar no backend', () async {
    backendHas([]);
    sendingFails();
    final tasks = getIt<TaskUseCase>();

    final created = await tasks.createTask(title: '  Comprar pão ');
    expect(created.title.value, 'Comprar pão');
    expect(created.createdAt.isUtc, isTrue);
    expect(created.id, hasLength(36));
    await tasks.refreshTasks();

    final listed = await tasks.watchActiveTasks().first;
    expect(listed.single.id, created.id);
  });

  test('o logout, pelo registry do core, apaga as tarefas e as '
      'preferências', () async {
    backendHas([]);
    sendingFails();
    final tasks = getIt<TaskUseCase>();
    await tasks.createTask(title: 'Comprar pão');
    await tasks.setShowCompletedTasks(false);

    await cleaners.clearAll();

    // Sem lista guardada, a próxima abertura vai de novo ao backend.
    expect(await tasks.watchActiveTasks().first, isEmpty);
    expect(await tasks.showCompletedTasks(), isTrue);
    verify(
      () => api.get(TaskApiPaths.tasks, query: any(named: 'query')),
    ).called(1);
  });

  test('a fila se inscreve no OutboxRegistry: o logout a conta, e o worker '
      'do core a envia', () async {
    sendingFails();
    final tasks = getIt<TaskUseCase>();
    await tasks.createTask(title: 'Comprar pão');
    await pumpEventQueue();
    expect(await outboxes.pendingOperations(), 1);

    when(
      () => api.put(
        any(),
        body: any(named: 'body'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async => {'version': 1});
    final worker = OutboxSyncWorker(registry: outboxes, logger: FakeLogger());

    expect(await worker.run(), isFalse);
    expect(await outboxes.pendingOperations(), 0);
  });

  test('sem rede, nenhuma ação do módulo fica bloqueada: tudo é guardado '
      'e espera na fila, e só o gesto de atualizar mostra o erro', () async {
    // A lista já veio uma vez, e então a rede caiu de vez.
    backendHas([
      {
        'id': 't-1',
        'title': 'Pagar a luz',
        'status': 'open',
        'createdAt': '2026-10-27T09:00:00.000Z',
        'version': 2,
      },
    ]);
    final tasks = getIt<TaskUseCase>();
    await tasks.watchActiveTasks().first;
    const offline = ApiError(ApiErrorKind.unreachable);
    when(() => api.get(any(), query: any(named: 'query'))).thenThrow(offline);
    when(
      () => api.put(
        any(),
        body: any(named: 'body'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenThrow(offline);
    when(
      () => api.patch(
        any(),
        body: any(named: 'body'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenThrow(offline);

    final created = await tasks.createTask(title: 'Comprar pão');
    await tasks.renameTask(created.id, title: 'Comprar pão integral');
    await tasks.completeTask('t-1');
    await tasks.reopenTask('t-1');
    await tasks.archiveTask('t-1');
    await tasks.setShowCompletedTasks(false);
    await pumpEventQueue();

    final listed = await tasks.watchActiveTasks().first;
    expect(
      [for (final task in listed) task.title.value],
      ['Comprar pão integral'],
    );
    expect(await outboxes.pendingOperations(), 5);
    await expectLater(tasks.refreshTasks(), throwsA(isA<ApiError>()));
  });

  test('um conflito de propósito: duas edições sem rede, o 409 de versão, '
      'a tela de conflitos e "Manter a minha", que reenvia sobre a versão '
      'do servidor (capítulo 34)', () async {
    backendHas([
      {
        'id': 't-1',
        'title': 'Pagar a luz',
        'status': 'open',
        'createdAt': '2026-10-27T09:00:00.000Z',
        'version': 2,
      },
    ]);
    final tasks = getIt<TaskUseCase>();
    await tasks.watchActiveTasks().first;
    // Banco, fila e Streams encadeados: mais voltas que o padrão.
    Future<void> settle() => pumpEventQueue(times: 100);

    // Duas edições sem rede: ficam na fila, na ordem.
    const offline = ApiError(ApiErrorKind.unreachable);
    final patches = <Map<String, Object?>>[];
    Object? patchAnswer = offline;
    when(
      () => api.patch(
        any(),
        body: any(named: 'body'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((invocation) async {
      patches.add(invocation.namedArguments[#body] as Map<String, Object?>);
      final answer = patchAnswer;
      if (answer is ApiError) throw answer;
      return answer;
    });
    await tasks.completeTask('t-1');
    await tasks.renameTask('t-1', title: 'Pagar a luz de outubro');
    await settle();
    expect(await outboxes.pendingOperations(), 2);

    // A rede volta, mas outra pessoa já tinha mudado a tarefa: a versão 5
    // do servidor recusa a primeira edição, e a segunda espera a decisão.
    patchAnswer = const ApiError(
      ApiErrorKind.rejected,
      statusCode: 409,
      body: {'code': 'version_conflict'},
    );
    patches.clear();
    final worker = OutboxSyncWorker(registry: outboxes, logger: FakeLogger());
    await worker.run();
    expect(patches, hasLength(1));
    expect(patches.single['baseVersion'], 2);

    // A lista avisa, e a tela de conflitos mostra as duas versões.
    final list = getIt<TaskListBloc>()..add(const TaskListStarted());
    addTearDown(list.close);
    await settle();
    expect(list.state.conflicts, 1);

    when(() => api.get(TaskApiPaths.task('t-1'))).thenAnswer(
      (_) async => {
        'id': 't-1',
        'title': 'Pagar a conta de luz',
        'status': 'open',
        'createdAt': '2026-10-27T09:00:00.000Z',
        'version': 5,
      },
    );
    final screen = getIt<TaskConflictsBloc>()
      ..add(const TaskConflictsStarted());
    addTearDown(screen.close);
    await settle();
    final conflict = screen.state.conflicts.single;
    expect(conflict.reason, TaskConflictReason.versionConflict);
    expect(conflict.task.title.value, 'Pagar a luz de outubro');
    expect(conflict.task.status, TaskStatus.done);
    final server = screen.state.servers[conflict.id]! as ServerVersionFound;
    expect(server.task?.title.value, 'Pagar a conta de luz');

    // "Manter a minha": uma operação só, com tudo o que o usuário fez,
    // sobre a versão que o servidor tem agora.
    patchAnswer = {'version': 6};
    patches.clear();
    screen.add(TaskConflictResolved(conflict, TaskConflictChoice.keepMine));
    await settle();

    expect(patches, [
      {
        'title': 'Pagar a luz de outubro',
        'status': 'done',
        'operationId': isA<String>(),
        'baseVersion': 5,
      },
    ]);
    expect(screen.state.conflicts, isEmpty);
    expect(list.state.conflicts, 0);
    expect(await outboxes.pendingOperations(), 0);
  });

  test('as fábricas entregam um Bloc novo a cada tela', () {
    expect(getIt<TaskListBloc>(), isNot(same(getIt<TaskListBloc>())));
    expect(getIt<TaskEditBloc>(), isNot(same(getIt<TaskEditBloc>())));
    expect(getIt<TaskConflictsBloc>(), isNot(same(getIt<TaskConflictsBloc>())));
  });

  test('fechado o escopo da sessão, nada do módulo continua '
      'registrado', () async {
    await getIt.popScope();
    expect(getIt.isRegistered<TaskUseCase>(), isFalse);
  });
}
