import 'dart:async';

import 'package:auth_module/auth_module.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_tarefas_app/app.dart';
import 'package:mobile_tarefas_app/bootstrap/app_router.dart';
import 'package:mobile_tarefas_app/bootstrap/dependency_injection.dart';
import 'package:mobile_tarefas_app/language/language_selection_page.dart';
import 'package:mobile_tarefas_app/session/session_gate.dart';
import 'package:mobile_tarefas_app/settings/app_settings.dart';
import 'package:tasks_module/tasks_module.dart';

import 'support/fakes.dart';

void main() {
  late StreamController<SessionState> sessionChanges;
  late FakeConnectivityService connectivity;
  late FakeAnalytics analytics;

  // O auth_module de verdade, montado pela própria função de registro sobre
  // portas do core simuladas: a tela de login precisa do LoginBloc. Nenhum
  // teste aqui chega à rede ou ao banco.
  setUp(() {
    sessionChanges = StreamController<SessionState>.broadcast();
    connectivity = FakeConnectivityService();
    analytics = FakeAnalytics();
    getIt.pushNewScope(
      scopeName: 'test',
      init: (scope) {
        scope
          ..registerSingleton<ApiClient>(UnusedApiClient())
          ..registerSingleton<LocalDatabaseFactory>(FailingDatabaseFactory())
          ..registerSingleton<LogoutCleanerRegistry>(
            DefaultLogoutCleanerRegistry(),
          )
          ..registerSingleton<OutboxRegistry>(DefaultOutboxRegistry())
          ..registerSingleton<AppLogger>(FakeLogger())
          ..registerSingleton<AppAnalytics>(analytics);
        registerAuthModuleDependencies(scope);
        registerTasksModuleDependencies(scope);
      },
    );
  });
  tearDown(() => getIt.popScopesTill('test'));

  Future<AppSettings> settingsWith(FakePreferences preferences) =>
      AppSettings.load(
        preferences: preferences,
        logger: FakeLogger(),
        timeout: const Duration(seconds: 1),
      );

  Future<void> pumpApp(
    WidgetTester tester,
    AppSettings settings, {
    required SessionState session,
  }) async {
    // Desfeitos na ordem inversa: o roteador antes do que ele escuta.
    addTearDown(settings.dispose);
    final gate = SessionGate(
      initial: session,
      changes: sessionChanges.stream,
      onSignedIn: () {},
      onSignedOut: () async {},
    );
    addTearDown(gate.dispose);
    final router = createAppRouter(settings, gate, analytics: analytics);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MobileTarefasApp(
        settings: settings,
        router: router,
        connectivity: connectivity,
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder loginScreen() => find.text('Acesse sua conta');

  testWidgets('na primeira abertura, o app pergunta o idioma e, sem sessão, '
      'segue para o login', (tester) async {
    final preferences = FakePreferences();
    final settings = await settingsWith(preferences);
    await pumpApp(tester, settings, session: const SessionUnauthenticated());

    expect(find.byType(LanguageSelectionPage), findsOneWidget);
    // Enquanto não há escolha, o locale é o do ARB template, nunca nulo.
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('en'),
    );

    await tester.tap(find.text('Português (Brasil)'));
    await tester.pumpAndSettle();

    expect(preferences.storedLanguage, 'pt-BR');
    expect(loginScreen(), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('pt', 'BR'),
    );
  });

  testWidgets('com o idioma e a sessão guardados, abre direto na lista de '
      'tarefas, com o tema escolhido', (tester) async {
    final settings = await settingsWith(
      FakePreferences(
        storedLanguage: 'pt-BR',
        storedThemeMode: AppThemeMode.dark,
      ),
    );
    await pumpApp(tester, settings, session: const SessionAuthenticated());

    // A lista do módulo de tarefas; sem banco no teste, a falha da
    // primeira carga, com a opção de tentar de novo.
    expect(find.text('Tarefas'), findsOneWidget);
    expect(find.text('Não foi possível carregar as tarefas'), findsOneWidget);
    // O botão de sair do auth_module, na moldura da tela (capítulo 29).
    expect(find.text('Sair'), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.darkTheme?.colorScheme, AppTheme.dark.colorScheme);
  });

  testWidgets('o login leva à tela inicial, e o fim da sessão, de volta ao '
      'login', (tester) async {
    final settings = await settingsWith(
      FakePreferences(storedLanguage: 'pt-BR'),
    );
    await pumpApp(tester, settings, session: const SessionUnauthenticated());
    expect(loginScreen(), findsOneWidget);

    sessionChanges.add(const SessionAuthenticated());
    await tester.pumpAndSettle();
    expect(find.text('Tarefas'), findsOneWidget);

    sessionChanges.add(const SessionUnauthenticated());
    await tester.pumpAndSettle();
    expect(loginScreen(), findsOneWidget);
  });

  testWidgets('sem conexão, o aviso aparece abaixo da tela, que continua '
      'funcionando', (tester) async {
    final settings = await settingsWith(
      FakePreferences(storedLanguage: 'pt-BR'),
    );
    await pumpApp(tester, settings, session: const SessionUnauthenticated());
    expect(find.byType(AppConnectivityBanner), findsOneWidget);
    expect(find.textContaining('Sem conexão'), findsNothing);

    connectivity.emit(ConnectivityStatus.offline);
    await tester.pumpAndSettle();
    expect(find.textContaining('Sem conexão'), findsOneWidget);

    // O login continua tocável: o aviso não cobre nem bloqueia a tela.
    await tester.tap(find.text('Criar uma conta'));
    await tester.pumpAndSettle();
    expect(loginScreen(), findsNothing);
    expect(find.textContaining('Sem conexão'), findsOneWidget);

    connectivity.emit(ConnectivityStatus.online);
    await tester.pumpAndSettle();
    expect(find.textContaining('Sem conexão'), findsNothing);
  });

  testWidgets('o idioma escolhido traduz o host e os módulos, e a troca vale '
      'na hora, sem reiniciar o app', (tester) async {
    final preferences = FakePreferences(storedLanguage: 'en');
    final settings = await settingsWith(preferences);
    await pumpApp(tester, settings, session: const SessionAuthenticated());

    // Em inglês: a lista do módulo de tarefas, o botão do auth_module e o
    // aviso do host.
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text("Couldn't load the tasks"), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    connectivity.emit(ConnectivityStatus.offline);
    await tester.pumpAndSettle();
    expect(find.textContaining('No connection.'), findsOneWidget);

    // Uma tela de configurações de qualquer módulo só grava pela porta; o
    // host escuta e aplica.
    await preferences.saveLanguageCode('pt-BR');
    await tester.pumpAndSettle();

    expect(find.text('Tarefas'), findsOneWidget);
    expect(find.text('Não foi possível carregar as tarefas'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
    expect(find.textContaining('Sem conexão.'), findsOneWidget);
    // Os textos do próprio Flutter também: o delegate global segue o locale.
    final context = tester.element(find.text('Tarefas'));
    expect(Localizations.localeOf(context), const Locale('pt', 'BR'));
    expect(MaterialLocalizations.of(context).cancelButtonLabel, 'Cancelar');
  });

  testWidgets('o idioma do sistema nunca entra: com outro idioma no '
      'aparelho e nada escolhido, o app pergunta, em inglês', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('pt', 'BR')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final settings = await settingsWith(FakePreferences());
    await pumpApp(tester, settings, session: const SessionUnauthenticated());

    expect(find.byType(LanguageSelectionPage), findsOneWidget);
    final context = tester.element(find.byType(LanguageSelectionPage));
    expect(Localizations.localeOf(context), const Locale('en'));
  });

  testWidgets('cada tela vista é registrada pelo nome da rota, inclusive as '
      'da moldura, que tem navegador próprio', (tester) async {
    final settings = await settingsWith(FakePreferences());
    await pumpApp(tester, settings, session: const SessionUnauthenticated());
    expect(analytics.screens, ['app.language']);

    await tester.tap(find.text('Português (Brasil)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar uma conta'));
    await tester.pumpAndSettle();
    expect(analytics.screens, ['app.language', 'auth.login', 'auth.register']);

    // A lista de tarefas mora no ShellRoute do host.
    sessionChanges.add(const SessionAuthenticated());
    await tester.pumpAndSettle();
    expect(analytics.screens.last, 'tasks.list');
  });
}
