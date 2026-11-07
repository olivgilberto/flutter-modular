import 'package:adapter_connectivity_connectivity_plus/adapter_connectivity_connectivity_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

final class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockConnectivity connectivity;
  late ConnectivityPlusNetworkInterfaceMonitor monitor;

  setUp(() {
    connectivity = _MockConnectivity();
    monitor = ConnectivityPlusNetworkInterfaceMonitor(
      connectivity: connectivity,
    );
  });

  test('qualquer resultado diferente de none conta como interface', () async {
    when(() => connectivity.checkConnectivity()).thenAnswer(
      (_) async => [ConnectivityResult.none, ConnectivityResult.mobile],
    );

    expect(await monitor.hasNetworkInterface(), isTrue);
  });

  test('só none é falta de interface', () async {
    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.none]);

    expect(await monitor.hasNetworkInterface(), isFalse);
  });

  test('falha do plugin supõe que há interface', () async {
    when(
      () => connectivity.checkConnectivity(),
    ).thenThrow(PlatformException(code: 'indisponivel'));

    expect(await monitor.hasNetworkInterface(), isTrue);
  });

  test('as mudanças viram booleanos, sem repetição', () async {
    when(() => connectivity.onConnectivityChanged).thenAnswer(
      (_) => Stream.fromIterable([
        [ConnectivityResult.wifi],
        [ConnectivityResult.mobile],
        [ConnectivityResult.none],
      ]),
    );

    expect(await monitor.networkInterfaceChanges.toList(), [true, false]);
  });
}
