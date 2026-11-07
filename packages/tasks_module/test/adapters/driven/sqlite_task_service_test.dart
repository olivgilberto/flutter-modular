import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_module/adapters/driven/models/task_model.dart';
import 'package:tasks_module/adapters/driven/services/sqlite_task_service.dart';
import 'package:tasks_module/adapters/driven/services/tasks_database_schema.dart';
import 'package:tasks_module/adapters/driven/sync/task_conflict_store.dart';
import 'package:tasks_module/domain/entities/task.dart';
import 'package:tasks_module/domain/entities/task_conflict.dart';
import 'package:tasks_module/domain/value_objects/task_title.dart';

import '../../support/ffi_local_database.dart';

Task _task(
  String id,
  String title, {
  int minute = 0,
  TaskStatus status = TaskStatus.open,
}) => Task(
  id: id,
  title: TaskTitle.parse(title),
  createdAt: DateTime.utc(2026, 10, 27, 9, minute),
  status: status,
);

TaskModel _remote(
  String id,
  String title, {
  int minute = 0,
  String status = 'open',
  int version = 1,
}) => TaskModel(
  id: id,
  title: title,
  status: status,
  createdAt: DateTime.utc(2026, 10, 27, 9, minute).millisecondsSinceEpoch,
  version: version,
);

List<String> _titles(List<Task> tasks) => [
  for (final task in tasks) task.title.value,
];

void main() {
  final now = DateTime.utc(2026, 10, 27, 12);
  late FfiLocalDatabaseFactory factory;
  late SqliteTaskService service;
  late int nextOperation;

  setUp(() {
    nextOperation = 0;
    factory = FfiLocalDatabaseFactory();
    service = SqliteTaskService(
      databaseFactory: factory,
      newOperationId: () => 'op-${++nextOperation}',
      now: () => now,
    );
  });

  tearDown(() async {
    await service.dispose();
    await factory.close();
  });

  /// A fila, na ordem de envio, lida direto do banco.
  Future<List<Map<String, Object?>>> operations() async {
    final db = await factory.rawDatabase(tasksDatabaseSchema);
    return [
      for (final row in await db.rawQuery(
        'SELECT * FROM outbox_pending_operations ORDER BY rowid',
      ))
        {...row, 'payload': jsonDecode(row['payload']! as String)},
    ];
  }

  test('grava e encontra uma tarefa', () async {
    await service.saveTask(_task('t-1', 'Comprar pão'));

    final found = await service.findTask('t-1');
    expect(found?.title.value, 'Comprar pão');
    expect(found?.createdAt, DateTime.utc(2026, 10, 27, 9));
    expect(await service.findTask('t-9'), isNull);
  });

  test('gravar de novo atualiza título e situação, nunca a data de '
      'criação', () async {
    await service.saveTask(_task('t-1', 'Comprar pão'));
    await service.saveTask(
      _task('t-1', 'Comprar pão integral', minute: 30, status: TaskStatus.done),
    );

    final found = await service.findTask('t-1');
    expect(found?.title.value, 'Comprar pão integral');
    expect(found?.status, TaskStatus.done);
    expect(found?.createdAt, DateTime.utc(2026, 10, 27, 9));
  });

  test('cada escrita põe na fila, na mesma transação, a operação que o '
      'backend precisa receber', () async {
    await service.saveTask(_task('t-1', 'Comprar pão'));
    await service.saveActiveTasks([
      _remote('t-2', 'Pagar a luz', version: 7),
    ], refreshedAt: now);
    await service.saveTask(
      _task('t-2', 'Pagar a luz', status: TaskStatus.done),
    );
    await service.archiveTask('t-2');
    await service.archiveTask('t-9');

    expect(await operations(), [
      {
        'id': 'op-1',
        'entity_id': 't-1',
        'operation': 'create',
        'payload': {
          'title': 'Comprar pão',
          'status': 'open',
          'createdAt': '2026-10-27T09:00:00.000Z',
        },
        'base_version': null,
        'created_at': now.millisecondsSinceEpoch,
      },
      {
        'id': 'op-2',
        'entity_id': 't-2',
        'operation': 'update',
        'payload': {'title': 'Pagar a luz', 'status': 'done'},
        'base_version': 7,
        'created_at': now.millisecondsSinceEpoch,
      },
      {
        'id': 'op-3',
        'entity_id': 't-2',
        'operation': 'archive',
        'payload': {'status': 'archived'},
        'base_version': 7,
        'created_at': now.millisecondsSinceEpoch,
      },
    ]);
  });

  group('a fila, do lado de quem envia', () {
    /// A versão de cada tarefa, lida direto do banco.
    Future<Map<String, int>> versions() async {
      final db = await factory.rawDatabase(tasksDatabaseSchema);
      return {
        for (final row in await db.rawQuery('SELECT id, version FROM tasks'))
          row['id']! as String: row['version']! as int,
      };
    }

    test('lê as operações na ordem em que foram gravadas', () async {
      await service.saveTask(_task('t-1', 'Comprar pão'));
      await service.archiveTask('t-1');

      final pending = await service.pendingInOrder();
      expect([for (final op in pending) op.id], ['op-1', 'op-2']);
      expect(pending.first.payload['title'], 'Comprar pão');
      expect(pending.last.baseVersion, 0);
      expect(await service.pendingCount(), 2);
    });

    test('aceita, a operação sai da fila, a tarefa guarda a versão nova, e '
        'as seguintes da mesma tarefa passam a se apoiar nela', () async {
      await service.saveActiveTasks([
        _remote('t-2', 'Pagar a luz', version: 7),
      ], refreshedAt: now);
      await service.saveTask(_task('t-1', 'Comprar pão'));
      await service.saveTask(_task('t-1', 'Comprar pão integral'));
      await service.saveTask(
        _task('t-2', 'Pagar a luz', status: TaskStatus.done),
      );
      final created = (await service.pendingInOrder()).first;

      await service.complete(created, newVersion: 1);
      // O outro isolate já tinha confirmado a mesma operação: nada muda.
      await service.complete(created, newVersion: 1);

      expect(await versions(), {'t-1': 1, 't-2': 7});
      expect(
        [for (final op in await operations()) (op['id'], op['base_version'])],
        [('op-2', 1), ('op-3', 7)],
      );
    });

    test('a versão da tarefa nunca anda para trás', () async {
      await service.saveTask(_task('t-1', 'Comprar pão'));
      final created = (await service.pendingInOrder()).single;
      final db = await factory.rawDatabase(tasksDatabaseSchema);
      await db.rawUpdate("UPDATE tasks SET version = 5 WHERE id = 't-1'");

      await service.complete(created, newVersion: 1);

      expect(await versions(), {'t-1': 5});
    });

    test('recusada, a operação sai da fila e vira recusa uma vez só, e a '
        'atualização da lista não toca a tarefa', () async {
      await service.saveActiveTasks([
        _remote('t-1', 'Comprar pão', version: 3),
      ], refreshedAt: now);
      await service.saveTask(
        _task('t-1', 'Comprar pão', status: TaskStatus.done),
      );
      final update = (await service.pendingInOrder()).single;

      await service.moveFromQueue(
        update,
        kind: TaskConflictKind.conflict,
        statusCode: 409,
      );
      await service.moveFromQueue(
        update,
        kind: TaskConflictKind.conflict,
        statusCode: 409,
      );
      await service.saveActiveTasks([
        _remote('t-1', 'Comprar pão', version: 4),
      ], refreshedAt: now);

      expect(await operations(), isEmpty);
      expect(await service.pendingCount(), 0);
      expect(await service.openConflictCount(), 1);
      expect(await service.entitiesWithOpenConflict(), {'t-1'});
      expect((await service.findTask('t-1'))?.status, TaskStatus.done);
      final db = await factory.rawDatabase(tasksDatabaseSchema);
      final conflict = (await db.rawQuery(
        'SELECT * FROM sync_conflicts',
      )).single;
      expect(conflict['operation_id'], 'op-1');
      expect(conflict['kind'], 'conflict');
      expect(conflict['status_code'], 409);
      expect(conflict['operation'], 'update');
      expect(conflict['base_version'], 3);
      expect(jsonDecode(conflict['payload']! as String), {
        'title': 'Comprar pão',
        'status': 'done',
      });
    });

    test('tirar da fila sem tocar na tarefa', () async {
      await service.saveTask(_task('t-1', 'Comprar pão'));
      await service.remove('op-1');
      await service.remove('op-1');

      expect(await operations(), isEmpty);
      expect(await versions(), {'t-1': 0});
    });

    test('uma operação fora do formato é LocalDatabaseError', () async {
      final database = await factory.open(tasksDatabaseSchema);
      await database.execute(
        'INSERT INTO outbox_pending_operations VALUES '
        "('op-9', 't-1', 'create', 'não é json', NULL, 0)",
      );

      await expectLater(
        service.pendingInOrder(),
        throwsA(isA<LocalDatabaseError>()),
      );
    });
  });

  test('a lista observada chega na hora e de novo a cada escrita, das mais '
      'novas para as mais antigas e sem as arquivadas', () async {
    final lists = <List<String>>[];
    final subscription = service.watchActiveTasks().listen(
      (tasks) => lists.add(_titles(tasks)),
    );
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    await service.saveTask(_task('t-1', 'Comprar pão', minute: 1));
    await pumpEventQueue();
    await service.saveTask(
      _task('t-2', 'Pagar a luz', minute: 2, status: TaskStatus.done),
    );
    await pumpEventQueue();
    await service.archiveTask('t-1');
    await pumpEventQueue();

    expect(lists, [
      <String>[],
      ['Comprar pão'],
      ['Pagar a luz', 'Comprar pão'],
      ['Pagar a luz'],
    ]);
    expect((await service.findTask('t-1'))?.status, TaskStatus.archived);
  });

  test('a lista do backend substitui a do aparelho, com a versão do '
      'servidor, e avisa quem observa', () async {
    await service.saveActiveTasks([
      _remote('t-1', 'Comprar pão', minute: 1),
      _remote('t-2', 'Pagar a luz', minute: 2),
    ], refreshedAt: now);
    final lists = <List<String>>[];
    final subscription = service.watchActiveTasks().listen(
      (tasks) => lists.add(_titles(tasks)),
    );
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    await service.saveActiveTasks([
      _remote('t-2', 'Pagar a conta de luz', minute: 2, version: 2),
    ], refreshedAt: now);
    await pumpEventQueue();

    expect(lists, [
      ['Pagar a luz', 'Comprar pão'],
      ['Pagar a conta de luz'],
    ]);
    expect(await service.findTask('t-1'), isNull);
    expect(await operations(), isEmpty);
  });

  test('o servidor não apaga nem sobrescreve uma tarefa com operação na '
      'fila', () async {
    await service.saveActiveTasks([
      _remote('t-1', 'Comprar pão', minute: 1),
      _remote('t-2', 'Pagar a luz', minute: 2),
    ], refreshedAt: now);
    // Feito sem rede: uma tarefa nova, uma concluída e uma arquivada.
    await service.saveTask(_task('t-3', 'Ligar para a escola', minute: 3));
    await service.saveTask(
      _task('t-1', 'Comprar pão', minute: 1, status: TaskStatus.done),
    );
    await service.archiveTask('t-2');

    // O backend ainda não recebeu nada disso.
    await service.saveActiveTasks([
      _remote('t-1', 'Comprar pão', minute: 1, version: 3),
      _remote('t-2', 'Pagar a luz', minute: 2, version: 3),
    ], refreshedAt: now);

    expect((await service.findTask('t-1'))?.status, TaskStatus.done);
    expect((await service.findTask('t-2'))?.status, TaskStatus.archived);
    expect((await service.findTask('t-3'))?.title.value, 'Ligar para a escola');
    expect(await operations(), hasLength(3));
  });

  test('a hora da última atualização só existe depois da primeira', () async {
    expect(await service.lastRefreshedAt(), isNull);

    await service.saveActiveTasks([], refreshedAt: now);

    final refreshedAt = await service.lastRefreshedAt();
    expect(refreshedAt, now);
    expect(refreshedAt?.isUtc, isTrue);
  });

  test('as concluídas aparecem até o usuário escolher', () async {
    expect(await service.showCompletedTasks(), isTrue);

    await service.saveShowCompletedTasks(false);
    expect(await service.showCompletedTasks(), isFalse);
    await service.saveShowCompletedTasks(true);
    expect(await service.showCompletedTasks(), isTrue);
  });

  test('apagar tudo leva as tarefas, a fila, as recusas, a hora da '
      'atualização e as preferências, e avisa quem observa', () async {
    await service.saveActiveTasks([
      _remote('t-1', 'Comprar pão'),
    ], refreshedAt: now);
    await service.saveTask(_task('t-2', 'Pagar a luz'));
    await service.saveTask(_task('t-3', 'Ligar para a escola'));
    await service.moveFromQueue(
      (await service.pendingInOrder()).last,
      kind: TaskConflictKind.rejected,
      statusCode: 422,
    );
    await service.saveShowCompletedTasks(false);
    final lists = <List<String>>[];
    final subscription = service.watchActiveTasks().listen(
      (tasks) => lists.add(_titles(tasks)),
    );
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    await service.deleteAll();
    await pumpEventQueue();

    expect(lists.last, isEmpty);
    expect(await service.findTask('t-1'), isNull);
    expect(await operations(), isEmpty);
    expect(await service.openConflictCount(), 0);
    expect(await service.lastRefreshedAt(), isNull);
    expect(await service.showCompletedTasks(), isTrue);
  });

  test('uma linha que o domínio recusa chega como LocalDatabaseError, na '
      'busca e na lista observada', () async {
    // Gravada direto no banco, como uma versão antiga ou um bug a deixaria.
    final database = await factory.open(tasksDatabaseSchema);
    await database.execute(
      "INSERT INTO tasks VALUES ('t-1', '   ', 'open', 0, 0)",
    );

    await expectLater(
      service.findTask('t-1'),
      throwsA(isA<LocalDatabaseError>()),
    );
    await expectLater(
      service.watchActiveTasks(),
      emitsError(isA<LocalDatabaseError>()),
    );
  });

  test('o banco recusa uma situação fora da lista', () async {
    final database = await factory.open(tasksDatabaseSchema);
    await expectLater(
      database.execute(
        "INSERT INTO tasks VALUES ('t-1', 'x', 'deleted', 0, 0)",
      ),
      throwsA(isA<LocalDatabaseError>()),
    );
  });

  group('as recusas, do lado de quem decide (capítulo 34)', () {
    /// Uma tarefa do servidor, alterada no aparelho, e a alteração recusada.
    /// Depois da recusa, outra alteração espera na fila; a arquivada não tem
    /// alteração seguinte.
    Future<TaskConflict> refused({
      TaskConflictKind kind = TaskConflictKind.conflict,
      bool archived = false,
    }) async {
      await service.saveActiveTasks([
        _remote('t-1', 'Comprar pão', version: 3),
      ], refreshedAt: now);
      if (archived) {
        await service.archiveTask('t-1');
      } else {
        await service.saveTask(
          _task('t-1', 'Comprar pão', status: TaskStatus.done),
        );
      }
      final operation = (await service.pendingInOrder()).single;
      await service.moveFromQueue(
        operation,
        kind: kind,
        statusCode: kind == TaskConflictKind.conflict ? 409 : 422,
      );
      if (!archived) {
        await service.saveTask(
          _task('t-1', 'Comprar pão integral', status: TaskStatus.done),
        );
      }
      return (await service.watchConflicts().first).single;
    }

    Future<int?> refreshedAt() async {
      final db = await factory.rawDatabase(tasksDatabaseSchema);
      final rows = await db.rawQuery('SELECT refreshed_at FROM sync_state');
      return rows.isEmpty ? null : rows.single['refreshed_at'] as int?;
    }

    test('a recusa chega como conflito do domínio, com a tarefa do '
        'aparelho', () async {
      final conflict = await refused();

      expect(conflict.id, isNotEmpty);
      expect(conflict.reason, TaskConflictReason.versionConflict);
      expect(conflict.task.title.value, 'Comprar pão integral');
      expect(conflict.task.status, TaskStatus.done);
      expect(conflict.createdAt, now);
      expect(conflict.choices, [
        TaskConflictChoice.keepMine,
        TaskConflictChoice.keepServer,
      ]);
    });

    test('outra recusa 4xx chega como recusa', () async {
      final conflict = await refused(kind: TaskConflictKind.rejected);

      expect(conflict.reason, TaskConflictReason.rejected);
    });

    test('a lista de conflitos é observada e avisa a cada recusa', () async {
      final seen = <int>[];
      final subscription = service.watchConflicts().listen(
        (conflicts) => seen.add(conflicts.length),
      );
      await pumpEventQueue();

      await refused();
      await pumpEventQueue();

      expect(seen.first, 0);
      expect(seen.last, 1);
      await subscription.cancel();
    });

    test('manter a minha: uma operação só, com a versão do aparelho e a '
        'base do servidor', () async {
      final conflict = await refused();

      await service.keepLocalVersion(
        conflict.id,
        taskId: 't-1',
        serverVersion: 5,
      );

      expect(await service.watchConflicts().first, isEmpty);
      final ops = await operations();
      expect(ops, hasLength(1));
      expect(ops.single['operation'], 'update');
      expect(ops.single['base_version'], 5);
      expect(ops.single['payload'], {
        'title': 'Comprar pão integral',
        'status': 'done',
      });
      expect(await service.entitiesWithOpenConflict(), isEmpty);
    });

    test('manter a minha, arquivada aqui: o arquivamento com a base do '
        'servidor', () async {
      final conflict = await refused(archived: true);

      await service.keepLocalVersion(
        conflict.id,
        taskId: 't-1',
        serverVersion: 5,
      );

      final op = (await operations()).single;
      expect(op['operation'], 'archive');
      expect(op['payload'], {'status': 'archived'});
      expect(op['base_version'], 5);
    });

    test('manter a minha, apagada no servidor: volta como criação, com o '
        'mesmo id', () async {
      final conflict = await refused();

      await service.keepLocalVersion(
        conflict.id,
        taskId: 't-1',
        serverVersion: null,
      );

      final op = (await operations()).single;
      expect(op['operation'], 'create');
      expect(op['entity_id'], 't-1');
      expect(op['payload'], {
        'title': 'Comprar pão integral',
        'status': 'done',
        'createdAt': '2026-10-27T09:00:00.000Z',
      });
    });

    test(
      'manter a minha, apagada lá e arquivada aqui: nada a enviar',
      () async {
        final conflict = await refused(archived: true);

        await service.keepLocalVersion(
          conflict.id,
          taskId: 't-1',
          serverVersion: null,
        );

        expect(await operations(), isEmpty);
        expect(await service.findTask('t-1'), isNull);
      },
    );

    test('manter a do servidor: a versão dele fica, e a fila da tarefa '
        'esvazia', () async {
      final conflict = await refused();

      await service.acceptServerVersion(
        conflict.id,
        taskId: 't-1',
        server: _remote('t-1', 'Comprar pão francês', version: 6),
      );

      expect(await operations(), isEmpty);
      expect(await service.watchConflicts().first, isEmpty);
      final task = await service.findTask('t-1');
      expect(task?.title.value, 'Comprar pão francês');
      expect(task?.status, TaskStatus.open);
      expect(task?.createdAt, DateTime.utc(2026, 10, 27, 9));
    });

    test('manter a do servidor, apagada lá: some daqui também', () async {
      final conflict = await refused();

      await service.acceptServerVersion(
        conflict.id,
        taskId: 't-1',
        server: null,
      );

      expect(await service.findTask('t-1'), isNull);
      expect(await operations(), isEmpty);
    });

    test('descartar: a alteração sai, e a lista vence para atualizar por '
        'trás', () async {
      final conflict = await refused(kind: TaskConflictKind.rejected);
      expect(await refreshedAt(), now.millisecondsSinceEpoch);

      await service.discardConflict(conflict.id, taskId: 't-1');

      expect(await operations(), isEmpty);
      expect(await service.watchConflicts().first, isEmpty);
      expect(await refreshedAt(), 0);
      // O aparelho mostra a versão dele até a atualização chegar.
      expect(
        (await service.findTask('t-1'))?.title.value,
        'Comprar pão integral',
      );
    });

    test('decidir sobre um conflito que já saiu não quebra nada', () async {
      final conflict = await refused();
      await service.discardConflict(conflict.id, taskId: 't-1');

      await service.discardConflict(conflict.id, taskId: 't-1');
      await service.keepLocalVersion('c-9', taskId: 't-9', serverVersion: 1);

      expect(await operations(), isEmpty);
    });

    test('as outras tarefas não são tocadas', () async {
      final conflict = await refused();
      await service.saveTask(_task('t-2', 'Pagar a luz'));

      await service.acceptServerVersion(
        conflict.id,
        taskId: 't-1',
        server: _remote('t-1', 'Comprar pão', version: 6),
      );

      expect([for (final op in await operations()) op['entity_id']], ['t-2']);
      expect((await service.findTask('t-2'))?.title.value, 'Pagar a luz');
    });
  });
}
