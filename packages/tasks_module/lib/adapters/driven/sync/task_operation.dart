import 'dart:convert';

/// O que uma operação da fila pede ao backend (capítulo 12).
enum TaskOperationKind { create, update, archive }

/// Uma linha de `outbox_pending_operations`, como o envio a lê.
final class TaskOperation {
  const TaskOperation({
    required this.id,
    required this.entityId,
    required this.kind,
    required this.payload,
    this.baseVersion,
  });

  /// Lê a linha da fila. Uma linha fora do formato é `FormatException`; o
  /// serviço a transforma em `LocalDatabaseError`.
  factory TaskOperation.fromMap(Map<String, Object?> row) {
    final payload = switch (row['payload']) {
      final String json => jsonDecode(json),
      _ => null,
    };
    final kind = switch (row['operation']) {
      final String name => TaskOperationKind.values.asNameMap()[name],
      _ => null,
    };
    return switch (row) {
      {
        'id': final String id,
        'entity_id': final String entityId,
        'base_version': final int? baseVersion,
      }
          when kind != null && payload is Map<String, Object?> =>
        TaskOperation(
          id: id,
          entityId: entityId,
          kind: kind,
          payload: payload,
          baseVersion: baseVersion,
        ),
      _ => throw const FormatException('operação da fila fora do formato'),
    };
  }

  /// Também o `Idempotency-Key` e o `operationId` do corpo.
  final String id;
  final String entityId;
  final TaskOperationKind kind;

  /// O que mudou, como o serviço gravou.
  final Map<String, Object?> payload;

  /// A versão do servidor sobre a qual o usuário agiu; `null` na criação.
  final int? baseVersion;

  /// A mesma operação, apoiada na versão que a anterior da tarefa recebeu.
  TaskOperation rebasedOn(int version) => TaskOperation(
    id: id,
    entityId: entityId,
    kind: kind,
    payload: payload,
    baseVersion: kind == TaskOperationKind.create ? null : version,
  );
}
