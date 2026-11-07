/// A fila de envio de um módulo (capítulo 12). Implementada no lado
/// driven do módulo e inscrita no [OutboxRegistry] pela função de registro
/// do próprio módulo.
abstract interface class SyncableOutbox {
  /// Nome da fila nos logs (por exemplo, 'tasks'). Nunca `runtimeType`,
  /// que é ofuscado nos builds de produção.
  String get name;

  /// Operações ainda não aceitas pelo servidor: as da fila e as que
  /// esperam uma decisão do usuário em sync_conflicts.
  Future<int> pendingCount();

  /// Envia as operações pendentes, na ordem em que foram gravadas.
  /// Devolve true quando alguma ficou para uma nova tentativa.
  /// Chamadas simultâneas compartilham o mesmo envio.
  Future<bool> sync();
}

abstract interface class OutboxRegistry {
  void register(SyncableOutbox outbox);
  Iterable<SyncableOutbox> get outboxes;

  /// Soma as operações pendentes de todas as filas, consultada antes do
  /// logout.
  Future<int> pendingOperations();

  /// Esquece as filas da sessão que terminou.
  void unregisterAll();
}

final class DefaultOutboxRegistry implements OutboxRegistry {
  final List<SyncableOutbox> _outboxes = [];

  @override
  void register(SyncableOutbox outbox) => _outboxes.add(outbox);

  @override
  Iterable<SyncableOutbox> get outboxes => List.unmodifiable(_outboxes);

  @override
  Future<int> pendingOperations() async {
    final counts = await Future.wait([
      for (final outbox in List.of(_outboxes)) outbox.pendingCount(),
    ]);
    return counts.fold<int>(0, (sum, count) => sum + count);
  }

  @override
  void unregisterAll() => _outboxes.clear();
}
