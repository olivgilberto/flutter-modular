import 'package:core/core.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  test('chamadas simultâneas compartilham a mesma execução', () async {
    final registry = DefaultOutboxRegistry();
    final outbox = FakeOutbox('tasks');
    registry.register(outbox);
    final orchestrator = SyncOrchestrator(
      connectivityService: DefaultConnectivityService(
        networkInterfaceMonitor: FakeMonitor(),
        reachabilityProbe: FakeProbe(),
      ),
      outboxSyncWorker: OutboxSyncWorker(
        registry: registry,
        logger: FakeLogger(),
      ),
    );

    await Future.wait([orchestrator.syncNow(), orchestrator.syncNow()]);

    expect(outbox.calls, 1);
  });

  test('sincroniza na transição para online', () async {
    final registry = DefaultOutboxRegistry();
    final outbox = FakeOutbox('tasks');
    registry.register(outbox);
    final monitor = FakeMonitor(hasInterface: false);
    final connectivity = DefaultConnectivityService(
      networkInterfaceMonitor: monitor,
      reachabilityProbe: FakeProbe(),
    );
    final orchestrator = SyncOrchestrator(
      connectivityService: connectivity,
      outboxSyncWorker: OutboxSyncWorker(
        registry: registry,
        logger: FakeLogger(),
      ),
      debounce: Duration.zero,
    );
    await connectivity.start();
    orchestrator.start();
    expect(outbox.calls, 0);

    monitor.hasInterface = true;
    monitor.changes.add(true);
    await connectivity.statusChanges.firstWhere(
      (status) => status == ConnectivityStatus.online,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(outbox.calls, 1);
    await orchestrator.dispose();
    await connectivity.dispose();
  });
}
