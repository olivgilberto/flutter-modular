import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_tarefas_app/l10n/mobile_tarefas_localizations.dart';
import 'package:mobile_tarefas_app/security/device_integrity.dart';

import '../support/fakes.dart';

void main() {
  late FakeLogger logger;
  late int jailbreakChecks;

  setUp(() {
    logger = FakeLogger();
    jailbreakChecks = 0;
  });

  Future<bool> check({
    bool real = true,
    bool jailBroken = false,
    Object? failure,
  }) => deviceCompromised(
    logger: logger,
    isRealDevice: () async {
      if (failure != null) throw failure;
      return real;
    },
    isJailBroken: () async {
      jailbreakChecks++;
      return jailBroken;
    },
  );

  test('emuladores e simuladores ficam de fora', () async {
    expect(await check(real: false, jailBroken: true), isFalse);
    expect(jailbreakChecks, 0);
  });

  test('um aparelho real com root ou jailbreak é apontado e '
      'registrado', () async {
    expect(await check(), isFalse);
    expect(await check(jailBroken: true), isTrue);
    expect(logger.logs, ['device integrity: root or jailbreak']);
  });

  test('na dúvida, nenhum aviso', () async {
    expect(await check(failure: PlatformException(code: 'x')), isFalse);
    expect(logger.errors, ['device integrity']);
  });

  testWidgets('o aviso aparece no alto, não bloqueia a tela e sai quando '
      'dispensado', (tester) async {
    final messenger = GlobalKey<ScaffoldMessengerState>();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('pt'),
        localizationsDelegates:
            MobileTarefasLocalizations.localizationsDelegates,
        supportedLocales: MobileTarefasLocalizations.supportedLocales,
        scaffoldMessengerKey: messenger,
        home: Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => taps++,
              child: const Text('Salvar'),
            ),
          ),
        ),
      ),
    );

    showDeviceIntegrityNotice(messenger.currentState!);
    await tester.pumpAndSettle();
    expect(find.textContaining('root ou jailbreak'), findsOneWidget);

    await tester.tap(find.text('Salvar'));
    expect(taps, 1);

    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('root ou jailbreak'), findsNothing);
  });
}
