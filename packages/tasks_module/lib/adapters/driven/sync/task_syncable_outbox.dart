import 'package:core/core.dart';

import '../task_api_paths.dart';
import 'task_conflict_store.dart';
import 'task_operation.dart';
import 'task_outbox_queue.dart';

/// A fila de envio das tarefas, inscrita no `OutboxRegistry` do `core`
/// (capítulo 12). Envia as operações na ordem em que foram gravadas e dá a
/// cada resposta um destino: sai da fila, fica na fila ou vai para
/// `sync_conflicts`. Nada sai da fila sem que o servidor o tenha aceitado
/// ou o usuário o tenha visto.
final class TaskSyncableOutbox implements SyncableOutbox {
  TaskSyncableOutbox({
    required ApiClient apiClient,
    required TaskOutboxQueue queue,
    required TaskConflictStore conflicts,
    required AppLogger logger,
  }) : _api = apiClient,
       _queue = queue,
       _conflicts = conflicts,
       _logger = logger;

  final ApiClient _api;
  final TaskOutboxQueue _queue;
  final TaskConflictStore _conflicts;
  final AppLogger _logger;
  Future<bool>? _running;

  @override
  String get name => 'tasks';

  /// As da fila e as que esperam decisão: nenhuma foi aceita pelo servidor.
  @override
  Future<int> pendingCount() async =>
      await _queue.pendingCount() + await _conflicts.openConflictCount();

  /// Quem chamar durante um envio recebe o mesmo. Vale dentro de um
  /// isolate; entre o app aberto e o segundo plano, quem protege é a
  /// idempotência (capítulo 12).
  @override
  Future<bool> sync() =>
      _running ??= _drain().whenComplete(() => _running = null);

  Future<bool> _drain() async {
    final blocked = await _conflicts.entitiesWithOpenConflict();
    // A versão que cada tarefa ganhou nesta rodada. A fila no banco já foi
    // reapoiada nela; a lista lida no começo, não.
    final accepted = <String, int>{};
    for (final queued in await _queue.pendingInOrder()) {
      // Feita sobre uma versão que o servidor já recusou: espera o usuário.
      if (blocked.contains(queued.entityId)) continue;
      final operation = switch (accepted[queued.entityId]) {
        final int version => queued.rebasedOn(version),
        null => queued,
      };
      try {
        final response = await _send(operation);
        if (await _complete(operation, response) case final int version) {
          accepted[operation.entityId] = version;
        }
      } on ApiError catch (error) {
        if (_shouldWait(error)) return true;
        if (_alreadyApplied(operation, error)) {
          await _queue.remove(operation.id);
          continue;
        }
        await _conflicts.moveFromQueue(
          operation,
          kind: _isVersionConflict(error)
              ? TaskConflictKind.conflict
              : TaskConflictKind.rejected,
          statusCode: error.statusCode ?? 0,
        );
        blocked.add(operation.entityId);
      }
    }
    return false;
  }

  /// O id da operação vai no corpo, que é o que o backend grava com a
  /// mudança, e no cabeçalho, como transporte.
  Future<Object?> _send(TaskOperation operation) {
    final path = TaskApiPaths.task(operation.entityId);
    final body = {...operation.payload, 'operationId': operation.id};
    return switch (operation.kind) {
      TaskOperationKind.create => _api.put(
        path,
        body: body,
        idempotencyKey: operation.id,
      ),
      TaskOperationKind.update || TaskOperationKind.archive => _api.patch(
        path,
        body: {...body, 'baseVersion': operation.baseVersion},
        idempotencyKey: operation.id,
      ),
    };
  }

  /// A versão nova vem na resposta, e as operações seguintes da tarefa
  /// passam a se apoiar nela. Sem ela, a operação sai da fila do mesmo
  /// jeito, porque o servidor a aplicou; a próxima atualização da lista
  /// traz a versão, e o defeito da resposta vai para o registro de falhas.
  Future<int?> _complete(TaskOperation operation, Object? response) async {
    if (response case {'version': final int version}) {
      await _queue.complete(operation, newVersion: version);
      return version;
    }
    await _queue.remove(operation.id);
    _logger.error(
      'tasks outbox response',
      const ApiError(ApiErrorKind.invalidResponse),
      StackTrace.current,
    );
    return null;
  }

  /// Esperar: falha transitória, resposta ilegível (não se sabe se foi
  /// aplicada), sessão expirada, servidor pedindo calma, ou um 409 que não
  /// é de versão, como o da mesma chave ainda em processamento.
  static bool _shouldWait(ApiError error) =>
      error.isTransient ||
      error.kind == ApiErrorKind.invalidResponse ||
      error.statusCode == 401 ||
      error.statusCode == 429 ||
      (error.statusCode == 409 && !_isVersionConflict(error));

  /// Arquivar o que já não existe no servidor é o resultado que a operação
  /// queria.
  static bool _alreadyApplied(TaskOperation operation, ApiError error) =>
      operation.kind == TaskOperationKind.archive && error.statusCode == 404;

  static bool _isVersionConflict(ApiError error) => switch (error) {
    ApiError(statusCode: 409, body: {'code': 'version_conflict'}) => true,
    _ => false,
  };
}
