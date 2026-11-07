import 'package:core/core.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  late FakeMonitor monitor;
  late FakeProbe probe;
  late DefaultConnectivityService service;

  setUp(() {
    monitor = FakeMonitor();
    probe = FakeProbe();
    service = DefaultConnectivityService(
      networkInterfaceMonitor: monitor,
      reachabilityProbe: probe,
    );
  });

  tearDown(() => service.dispose());

  test('começa como unknown', () {
    expect(service.status, ConnectivityStatus.unknown);
  });

  test('sem interface fica offline, sem chamar a sonda', () async {
    monitor.hasInterface = false;

    expect(await service.check(), ConnectivityStatus.offline);
    expect(probe.calls, 0);
  });

  test('interface sem backend é noInternet', () async {
    probe.reachable = false;

    expect(await service.check(), ConnectivityStatus.noInternet);
  });

  test('a mudança de interface dispara uma verificação', () async {
    monitor.hasInterface = false;
    await service.start();
    expect(service.status, ConnectivityStatus.offline);

    monitor.hasInterface = true;
    final online = service.statusChanges.firstWhere(
      (status) => status == ConnectivityStatus.online,
    );
    monitor.changes.add(true);

    expect(await online, ConnectivityStatus.online);
  });
}
