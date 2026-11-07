import 'dart:async';
import 'dart:convert';

import 'package:core/core.dart';

import '../../../domain/entities/task.dart';
import '../../../domain/entities/task_conflict.dart';
import '../../../domain/task_failure.dart';
import '../models/task_model.dart';
import '../sync/task_conflict_store.dart';
import '../sync/task_operation.dart';
import '../sync/task_outbox_queue.dart';
import 'task_local_service.dart';
import 'tasks_database_schema.dart';

/// As tarefas no banco criptografado do módulo, aberto pela porta
/// `LocalDatabaseFactory` no primeiro uso: a chave fica no armazenamento
/// seguro do aparelho, e o arquivo, fora do backup (capítulo 30).
///
/// A porta do banco não avisa mudanças, então o serviço avisa as suas:
/// cada escrita feita por ele relê a lista para quem a observa.
///
/// Também é a fila de envio e a tabela de recusas que o
/// `TaskSyncableOutbox` usa (capítulo 32): moram no mesmo banco, e a saída
/// da fila e a entrada na tabela de recusas precisam da mesma transação.
/// As escritas da fila não mudam o que a lista mostra, e por isso não
/// avisam; uma recusa nova avisa, para a tela de conflitos (capítulo 34).
/// O aviso vale só neste isolate: o que o segundo plano escreve aparece na
/// próxima leitura.
final class SqliteTaskService
    implements TaskLocalService, TaskOutboxQueue, TaskConflictStore {
  SqliteTaskService({
    required LocalDatabaseFactory databaseFactory,
    required String Function() newOperationId,
    required DateTime Function() now,
  }) : _databaseFactory = databaseFactory,
       _newOperationId = newOperationId,
       _now = now;

  static const _showCompletedKey = 'show_completed_tasks';
  static const _activeTasksKey = 'active_tasks';
  static const _columns = 'id, title, status, created_at, version';

  final LocalDatabaseFactory _databaseFactory;
  final String Function() _newOperationId;
  final DateTime Function() _now;
  final _changes = StreamController<void>.broadcast();

  /// A fábrica guarda o banco aberto e esquece uma abertura que falhou
  /// (capítulo 18).
  Future<LocalDatabase> get _database =>
      _databaseFactory.open(tasksDatabaseSchema);

  @override
  Stream<List<Task>> watchActiveTasks() => _watch(_activeTasks);

  @override
  Stream<List<TaskConflict>> watchConflicts() => _watch(_conflicts);

  /// Lê na hora e de novo a cada escrita deste serviço. Uma leitura de cada
  /// vez, na ordem das escritas: um resultado antigo nunca chega depois de
  /// um novo.
  Stream<T> _watch<T>(Future<T> Function() readAll) {
    late final StreamController<T> controller;
    StreamSubscription<void>? changes;
    var listening = true;
    var reading = Future<void>.value();
    void read() {
      reading = reading.then((_) async {
        try {
          final result = await readAll();
          if (listening) controller.add(result);
        } on LocalDatabaseError catch (error, stackTrace) {
          if (listening) controller.addError(error, stackTrace);
        }
      });
    }

    controller = StreamController<T>(
      onListen: () {
        changes = _changes.stream.listen((_) => read());
        read();
      },
      onCancel: () {
        listening = false;
        return changes?.cancel();
      },
    );
    return controller.stream;
  }

  Future<List<Task>> _activeTasks() async {
    final rows = await (await _database).query(
      'SELECT $_columns FROM tasks '
      "WHERE status IN ('open', 'done') "
      'ORDER BY created_at DESC, id',
    );
    return [for (final row in rows) _toEntity(row)];
  }

  @override
  Future<Task?> findTask(String taskId) async {
    final rows = await (await _database).query(
      'SELECT $_columns FROM tasks WHERE id = ?',
      args: [taskId],
    );
    return rows.isEmpty ? null : _toEntity(rows.single);
  }

  /// A tarefa e a operação que leva a mudança ao backend, numa transação
  /// só: ou as duas ficam, ou nenhuma (capítulo 12). Uma tarefa que ainda
  /// não existe no aparelho é criação; uma que existe é alteração, com a
  /// versão que o usuário tinha diante de si.
  @override
  Future<void> saveTask(Task task) async {
    final row = TaskModel.fromEntity(task).toMap();
    await (await _database).transaction((txn) async {
      final existing = await txn.query(
        'SELECT version FROM tasks WHERE id = ?',
        args: [task.id],
      );
      await txn.execute(
        'INSERT INTO tasks (id, title, status, created_at) '
        'VALUES (?, ?, ?, ?) '
        'ON CONFLICT (id) DO UPDATE SET '
        'title = excluded.title, status = excluded.status',
        args: [row['id'], row['title'], row['status'], row['created_at']],
      );
      if (existing.isEmpty) {
        await _enqueue(
          txn,
          taskId: task.id,
          operation: 'create',
          payload: {
            'title': row['title'],
            'status': row['status'],
            'createdAt': task.createdAt.toIso8601String(),
          },
        );
      } else {
        await _enqueue(
          txn,
          taskId: task.id,
          operation: 'update',
          payload: {'title': row['title'], 'status': row['status']},
          baseVersion: existing.single['version']! as int,
        );
      }
    });
    _changes.add(null);
  }

  @override
  Future<void> archiveTask(String taskId) async {
    await (await _database).transaction((txn) async {
      final existing = await txn.query(
        'SELECT version FROM tasks WHERE id = ?',
        args: [taskId],
      );
      if (existing.isEmpty) return;
      await txn.execute(
        "UPDATE tasks SET status = 'archived' WHERE id = ?",
        args: [taskId],
      );
      await _enqueue(
        txn,
        taskId: taskId,
        operation: 'archive',
        payload: {'status': 'archived'},
        baseVersion: existing.single['version']! as int,
      );
    });
    _changes.add(null);
  }

  /// O id da operação vira o Idempotency-Key do envio (capítulo 32).
  Future<void> _enqueue(
    LocalDatabase txn, {
    required String taskId,
    required String operation,
    required Map<String, Object?> payload,
    int? baseVersion,
  }) => txn.execute(
    'INSERT INTO outbox_pending_operations '
    '(id, entity_id, operation, payload, base_version, created_at) '
    'VALUES (?, ?, ?, ?, ?, ?)',
    args: [
      _newOperationId(),
      taskId,
      operation,
      jsonEncode(payload),
      baseVersion,
      _now().millisecondsSinceEpoch,
    ],
  );

  /// O servidor não pode apagar o que o usuário fez (capítulo 12): uma
  /// tarefa com operação na fila, ou com uma recusa à espera do usuário,
  /// fica como está no aparelho, venha ou não na lista. As outras passam a
  /// ser as do backend, e as que não vieram saem do aparelho.
  @override
  Future<void> saveActiveTasks(
    List<TaskModel> tasks, {
    required DateTime refreshedAt,
  }) async {
    await (await _database).transaction((txn) async {
      final pending = {
        for (final row in await txn.query(
          'SELECT entity_id FROM outbox_pending_operations '
          'UNION SELECT entity_id FROM sync_conflicts',
        ))
          row['entity_id']! as String,
      };
      final fresh = {for (final task in tasks) task.id};
      for (final row in await txn.query('SELECT id FROM tasks')) {
        final id = row['id']! as String;
        if (!fresh.contains(id) && !pending.contains(id)) {
          await txn.execute('DELETE FROM tasks WHERE id = ?', args: [id]);
        }
      }
      for (final task in tasks) {
        if (pending.contains(task.id)) continue;
        final row = task.toMap();
        await txn.execute(
          'INSERT INTO tasks ($_columns) VALUES (?, ?, ?, ?, ?) '
          'ON CONFLICT (id) DO UPDATE SET title = excluded.title, '
          'status = excluded.status, version = excluded.version',
          args: [
            row['id'],
            row['title'],
            row['status'],
            row['created_at'],
            row['version'],
          ],
        );
      }
      await txn.execute(
        'INSERT OR REPLACE INTO sync_state (key, refreshed_at) VALUES (?, ?)',
        args: [_activeTasksKey, refreshedAt.millisecondsSinceEpoch],
      );
    });
    _changes.add(null);
  }

  @override
  Future<DateTime?> lastRefreshedAt() async {
    final rows = await (await _database).query(
      'SELECT refreshed_at FROM sync_state WHERE key = ?',
      args: [_activeTasksKey],
    );
    if (rows.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      rows.single['refreshed_at']! as int,
      isUtc: true,
    );
  }

  @override
  Future<List<TaskOperation>> pendingInOrder() async {
    final rows = await (await _database).query(
      'SELECT id, entity_id, operation, payload, base_version '
      'FROM outbox_pending_operations ORDER BY rowid',
    );
    return [for (final row in rows) _toOperation(row)];
  }

  @override
  Future<int> pendingCount() => _count('outbox_pending_operations');

  @override
  Future<void> complete(
    TaskOperation operation, {
    required int newVersion,
  }) async {
    await (await _database).transaction((txn) async {
      final queued = await txn.query(
        'SELECT rowid AS position FROM outbox_pending_operations WHERE id = ?',
        args: [operation.id],
      );
      if (queued.isEmpty) return;
      await txn.execute(
        'DELETE FROM outbox_pending_operations WHERE id = ?',
        args: [operation.id],
      );
      // Nunca para trás: uma atualização da lista pode ter trazido uma
      // versão mais nova antes desta resposta.
      await txn.execute(
        'UPDATE tasks SET version = max(version, ?) WHERE id = ?',
        args: [newVersion, operation.entityId],
      );
      await txn.execute(
        'UPDATE outbox_pending_operations SET base_version = ? '
        "WHERE entity_id = ? AND rowid > ? AND operation <> 'create'",
        args: [newVersion, operation.entityId, queued.single['position']],
      );
    });
  }

  @override
  Future<void> remove(String operationId) async {
    await (await _database).execute(
      'DELETE FROM outbox_pending_operations WHERE id = ?',
      args: [operationId],
    );
  }

  @override
  Future<Set<String>> entitiesWithOpenConflict() async {
    final rows = await (await _database).query(
      'SELECT DISTINCT entity_id FROM sync_conflicts',
    );
    return {for (final row in rows) row['entity_id']! as String};
  }

  @override
  Future<int> openConflictCount() => _count('sync_conflicts');

  /// A operação vai como foi enviada, com a versão base que o servidor
  /// recusou: é o que a tela de resolução precisa mostrar.
  @override
  Future<void> moveFromQueue(
    TaskOperation operation, {
    required TaskConflictKind kind,
    required int statusCode,
  }) async {
    await (await _database).transaction((txn) async {
      await txn.execute(
        'DELETE FROM outbox_pending_operations WHERE id = ?',
        args: [operation.id],
      );
      await txn.execute(
        'INSERT INTO sync_conflicts (id, operation_id, entity_id, kind, '
        'status_code, operation, payload, base_version, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) '
        'ON CONFLICT (operation_id) DO NOTHING',
        args: [
          _newOperationId(),
          operation.id,
          operation.entityId,
          kind.name,
          statusCode,
          operation.kind.name,
          jsonEncode(operation.payload),
          operation.baseVersion,
          _now().millisecondsSinceEpoch,
        ],
      );
    });
    // A tela de conflitos deste isolate passa a mostrá-la (capítulo 34).
    _changes.add(null);
  }

  Future<int> _count(String table) async {
    final rows = await (await _database).query(
      'SELECT COUNT(*) AS total FROM $table',
    );
    return rows.single['total']! as int;
  }

  /// Gravada pelo próprio app: fora do formato, é defeito do banco.
  TaskOperation _toOperation(Map<String, Object?> row) {
    try {
      return TaskOperation.fromMap(row);
    } on FormatException catch (error) {
      throw LocalDatabaseError('operação da fila inválida: ${error.message}');
    }
  }

  Future<List<TaskConflict>> _conflicts() async {
    final rows = await (await _database).query(
      'SELECT c.id AS conflict_id, c.kind, c.created_at AS conflict_at, '
      't.id, t.title, t.status, t.created_at, t.version '
      'FROM sync_conflicts c JOIN tasks t ON t.id = c.entity_id '
      'ORDER BY c.created_at, c.rowid',
    );
    return [
      for (final row in rows)
        TaskConflict(
          id: row['conflict_id']! as String,
          reason: row['kind'] == 'conflict'
              ? TaskConflictReason.versionConflict
              : TaskConflictReason.rejected,
          task: _toEntity(row),
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row['conflict_at']! as int,
            isUtc: true,
          ),
        ),
    ];
  }

  @override
  Future<void> keepLocalVersion(
    String conflictId, {
    required String taskId,
    required int? serverVersion,
  }) async {
    await (await _database).transaction((txn) async {
      final rows = await txn.query(
        'SELECT $_columns FROM tasks WHERE id = ?',
        args: [taskId],
      );
      if (rows.isEmpty) return;
      final local = TaskModel.fromMap(rows.single);
      await _forget(txn, conflictId: conflictId, taskId: taskId);
      final archived = local.status == 'archived';
      if (serverVersion == null && archived) {
        // Apagada lá e arquivada aqui: as duas versões concordam que ela
        // saiu da lista, e não há o que enviar.
        await txn.execute('DELETE FROM tasks WHERE id = ?', args: [taskId]);
        return;
      }
      if (serverVersion == null) {
        // Apagada no servidor: a versão do usuário volta como criação, com
        // o mesmo id, pelo mesmo PUT idempotente.
        await txn.execute(
          'UPDATE tasks SET version = 0 WHERE id = ?',
          args: [taskId],
        );
        await _enqueue(
          txn,
          taskId: taskId,
          operation: 'create',
          payload: {
            'title': local.title,
            'status': local.status,
            'createdAt': DateTime.fromMillisecondsSinceEpoch(
              local.createdAt,
              isUtc: true,
            ).toIso8601String(),
          },
        );
        return;
      }
      await txn.execute(
        'UPDATE tasks SET version = ? WHERE id = ?',
        args: [serverVersion, taskId],
      );
      await _enqueue(
        txn,
        taskId: taskId,
        operation: archived ? 'archive' : 'update',
        payload: archived
            ? {'status': 'archived'}
            : {'title': local.title, 'status': local.status},
        baseVersion: serverVersion,
      );
    });
    _changes.add(null);
  }

  @override
  Future<void> acceptServerVersion(
    String conflictId, {
    required String taskId,
    required TaskModel? server,
  }) async {
    await (await _database).transaction((txn) async {
      await _forget(txn, conflictId: conflictId, taskId: taskId);
      if (server == null) {
        await txn.execute('DELETE FROM tasks WHERE id = ?', args: [taskId]);
        return;
      }
      final row = server.toMap();
      await txn.execute(
        'INSERT INTO tasks ($_columns) VALUES (?, ?, ?, ?, ?) '
        'ON CONFLICT (id) DO UPDATE SET title = excluded.title, '
        'status = excluded.status, version = excluded.version',
        args: [
          row['id'],
          row['title'],
          row['status'],
          row['created_at'],
          row['version'],
        ],
      );
    });
    _changes.add(null);
  }

  @override
  Future<void> discardConflict(
    String conflictId, {
    required String taskId,
  }) async {
    await (await _database).transaction((txn) async {
      await _forget(txn, conflictId: conflictId, taskId: taskId);
      // Vencida: a próxima abertura mostra o aparelho e atualiza por trás.
      await txn.execute(
        'INSERT OR REPLACE INTO sync_state (key, refreshed_at) VALUES (?, 0)',
        args: [_activeTasksKey],
      );
    });
    _changes.add(null);
  }

  /// O conflito e as operações da tarefa que esperavam por ele: foram
  /// feitas sobre a versão que o servidor recusou, e a decisão as substitui.
  Future<void> _forget(
    LocalDatabase txn, {
    required String conflictId,
    required String taskId,
  }) async {
    await txn.execute(
      'DELETE FROM sync_conflicts WHERE id = ?',
      args: [conflictId],
    );
    await txn.execute(
      'DELETE FROM outbox_pending_operations WHERE entity_id = ?',
      args: [taskId],
    );
  }

  /// Até o usuário escolher, as concluídas aparecem.
  @override
  Future<bool> showCompletedTasks() async {
    final rows = await (await _database).query(
      'SELECT value FROM preferences WHERE key = ?',
      args: [_showCompletedKey],
    );
    return rows.isEmpty || rows.single['value'] == '1';
  }

  @override
  Future<void> saveShowCompletedTasks(bool show) async {
    await (await _database).execute(
      'INSERT OR REPLACE INTO preferences (key, value) VALUES (?, ?)',
      args: [_showCompletedKey, show ? '1' : '0'],
    );
  }

  /// Numa transação: ou some tudo, ou nada.
  @override
  Future<void> deleteAll() async {
    await (await _database).transaction((txn) async {
      await txn.execute('DELETE FROM tasks');
      await txn.execute('DELETE FROM outbox_pending_operations');
      await txn.execute('DELETE FROM sync_conflicts');
      await txn.execute('DELETE FROM sync_state');
      await txn.execute('DELETE FROM preferences');
    });
    _changes.add(null);
  }

  /// Fecha os avisos de mudança, no fim do escopo da sessão.
  Future<void> dispose() => _changes.close();

  /// O dado foi gravado pelo próprio app: um título que o domínio recusa,
  /// ou uma linha fora do formato, não é culpa do usuário (capítulo 9).
  Task _toEntity(Map<String, Object?> row) {
    try {
      return TaskModel.fromMap(row).toEntity();
    } on FormatException catch (error) {
      throw LocalDatabaseError('tarefa guardada inválida: ${error.message}');
    } on TaskFailure {
      throw const LocalDatabaseError('tarefa guardada com título inválido');
    }
  }
}
