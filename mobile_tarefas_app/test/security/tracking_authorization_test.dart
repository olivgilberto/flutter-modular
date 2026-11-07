import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_tarefas_app/security/tracking_authorization.dart';

import '../support/fakes.dart';

void main() {
  late FakeLogger logger;
  late int requests;

  setUp(() {
    logger = FakeLogger();
    requests = 0;
  });

  Future<void> run({
    bool iOS = true,
    TrackingStatus status = TrackingStatus.notDetermined,
    Object? failure,
  }) => requestTrackingAuthorization(
    logger: logger,
    isIOS: () => iOS,
    status: () async {
      if (failure != null) throw failure;
      return status;
    },
    request: () async {
      requests++;
      return TrackingStatus.denied;
    },
  );

  test('pede uma vez, só no iOS e só enquanto ninguém respondeu', () async {
    await run(iOS: false);
    expect(requests, 0);

    await run(status: TrackingStatus.authorized);
    await run(status: TrackingStatus.denied);
    expect(requests, 0);

    await run();
    expect(requests, 1);
    expect(logger.logs, ['tracking authorization: denied']);
  });

  test('uma falha do plugin vai para o registro e não para o app', () async {
    await run(failure: PlatformException(code: 'x'));

    expect(requests, 0);
    expect(logger.errors, ['tracking authorization']);
  });

  testWidgets('espera o app ficar ativo', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    var active = false;
    final future = appActive(tester.binding)..then((_) => active = true);
    await tester.pump();
    expect(active, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await future;
    expect(active, isTrue);

    // Já ativo, completa na hora.
    await appActive(tester.binding);
  });
}
