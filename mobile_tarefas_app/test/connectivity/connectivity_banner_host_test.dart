import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_tarefas_app/connectivity/connectivity_banner_host.dart';
import 'package:mobile_tarefas_app/l10n/mobile_tarefas_localizations.dart';

import '../support/fakes.dart';

void main() {
  late FakeConnectivityService connectivity;
  late int taps;

  setUp(() {
    connectivity = FakeConnectivityService();
    taps = 0;
  });
  tearDown(() => connectivity.dispose());

  Future<void> pumpHost(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('pt'),
      localizationsDelegates: MobileTarefasLocalizations.localizationsDelegates,
      supportedLocales: MobileTarefasLocalizations.supportedLocales,
      home: ConnectivityBannerHost(
        connectivity: connectivity,
        child: Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => taps++,
              child: const Text('Salvar'),
            ),
          ),
        ),
      ),
    ),
  );

  bool bannerVisible(WidgetTester tester) => tester
      .widget<AppConnectivityBanner>(find.byType(AppConnectivityBanner))
      .visible;

  test('só há aviso sem interface ou sem resposta do backend', () {
    final l10n = lookupMobileTarefasLocalizations(const Locale('pt'));
    String? message(ConnectivityStatus status) =>
        ConnectivityBannerHost.messageFor(l10n, status);

    expect(message(ConnectivityStatus.unknown), isNull);
    expect(message(ConnectivityStatus.online), isNull);
    expect(message(ConnectivityStatus.offline), startsWith('Sem conexão.'));
    expect(
      message(ConnectivityStatus.noInternet),
      startsWith('Sem acesso ao servidor.'),
    );
  });

  testWidgets('o aviso segue o estado, e a tela continua tocável com ele '
      'visível', (tester) async {
    await pumpHost(tester);
    expect(bannerVisible(tester), isFalse);

    connectivity.emit(ConnectivityStatus.noInternet);
    await tester.pumpAndSettle();
    expect(bannerVisible(tester), isTrue);
    expect(find.textContaining('Sem acesso ao servidor'), findsOneWidget);

    await tester.tap(find.text('Salvar'));
    expect(taps, 1);

    connectivity.emit(ConnectivityStatus.offline);
    await tester.pumpAndSettle();
    expect(find.textContaining('Sem conexão'), findsOneWidget);

    connectivity.emit(ConnectivityStatus.online);
    await tester.pumpAndSettle();
    expect(bannerVisible(tester), isFalse);
  });

  testWidgets('um estado já conhecido aparece na primeira montagem', (
    tester,
  ) async {
    connectivity = FakeConnectivityService(ConnectivityStatus.offline);
    await pumpHost(tester);

    expect(bannerVisible(tester), isTrue);
  });
}
