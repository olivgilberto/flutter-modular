import 'dart:async';

import 'connectivity.dart';
import 'outbox_sync_worker.dart';

/// Camada 3, com o app aberto: decide quando sincronizar, a cada transição
/// para [ConnectivityStatus.online], com um pequeno intervalo para absorver
/// oscilações. O [OutboxSyncWorker] decide o quê; o `SyncScheduler` cobre o
/// app fechado. Uma execução por vez neste isolate.
final class SyncOrchestrator {
  SyncOrchestrator({
    required ConnectivityService connectivityService,
    required OutboxSyncWorker outboxSyncWorker,
    this.debounce = const Duration(seconds: 2),
  }) : _connectivityService = connectivityService,
       _outboxSyncWorker = outboxSyncWorker;

  final ConnectivityService _connectivityService;
  final OutboxSyncWorker _outboxSyncWorker;
  final Duration debounce;

  StreamSubscription<ConnectivityStatus>? _subscription;
  Timer? _debounceTimer;
  Future<bool>? _running;

  /// Chamado pelo mainCommon, depois de abrir o escopo da sessão, quando
  /// já existe um módulo com fila de envio (capítulo 33).
  void start() {
    _subscription ??= _connectivityService.statusChanges
        .where((status) => status == ConnectivityStatus.online)
        .listen((_) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(debounce, () => unawaited(syncNow()));
        });
    if (_connectivityService.status == ConnectivityStatus.online) {
      unawaited(syncNow());
    }
  }

  /// Junta-se à execução em andamento em vez de começar outra. Devolve se
  /// algo ficou para a próxima rodada.
  Future<bool> syncNow() =>
      _running ??= _outboxSyncWorker.run().whenComplete(() => _running = null);

  Future<void> dispose() async {
    _debounceTimer?.cancel();
    await _subscription?.cancel();
  }
}
