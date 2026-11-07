import 'dart:convert';
import 'dart:io';

import 'package:auth_module/adapters/driven/auth_api_paths.dart';
import 'package:auth_module/application/use_cases/auth_use_case.dart';
import 'package:auth_module/auth_module.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'fakes.dart';
import 'support/ffi_local_database.dart';

/// O hexágono inteiro: View, Bloc, caso de uso, Service e o banco da sessão
/// são os de verdade. Só as portas do core são simuladas, e o módulo é
/// montado pela própria função de registro, como o host vai fazer.
final class _MockApiClient extends Mock implements ApiClient {}

/// Os dados locais de outro módulo, que o auth_module não conhece.
final class _TasksCleaner implements ClearableOnLogout {
  var cleared = 0;

  @override
  Future<void> clearLocalData() async => cleared++;
}

/// A fila de envio de outro módulo, com duas alterações pendentes.
final class _TasksOutbox implements SyncableOutbox {
  @override
  String get name => 'tasks';

  @override
  Future<int> pendingCount() async => 2;

  @override
  Future<bool> sync() async => false;
}

/// Os dados locais de outro módulo que, ao serem apagados, anotam o que o
/// host via naquele momento.
final class _SessionSpy implements ClearableOnLogout {
  SessionState? seen;

  @override
  Future<void> clearLocalData() async =>
      seen = GetIt.instance<SessionBloc>().state;
}

const _password = 'cavalo-bateria-grampo';

final _signInResponse = jsonDecode(
  File('test/fixtures/sign_in_response.json').readAsStringSync(),
);

void main() {
  final getIt = GetIt.instance;
  late _MockApiClient api;
  late FfiLocalDatabaseFactory databases;
  late DefaultLogoutCleanerRegistry cleaners;
  late DefaultOutboxRegistry outboxes;
  late FakeLogger logger;
  late FakeAnalytics analytics;
  late _TasksCleaner tasks;

  /// O que o host fará no capítulo 28: registra as portas do core e chama a
  /// função do módulo. Chamada de novo, simula o app aberto outra vez com o
  /// mesmo aparelho (o mesmo banco) e a memória vazia.
  void startApp() => getIt.pushNewScope(
    scopeName: 'app',
    init: (scope) {
      scope
        ..registerSingleton<ApiClient>(api)
        ..registerSingleton<LocalDatabaseFactory>(databases)
        ..registerSingleton<LogoutCleanerRegistry>(cleaners)
        ..registerSingleton<OutboxRegistry>(outboxes)
        ..registerSingleton<AppLogger>(logger)
        ..registerSingleton<AppAnalytics>(analytics);
      registerAuthModuleDependencies(scope);
    },
  );

  Future<void> restartApp() async {
    await getIt.popScope();
    startApp();
  }

  AuthUseCase auth() => getIt<AuthUseCase>();
  Future<String?> token() => getIt<TokenProvider>().currentToken();

  // O `authenticated` entra nos stubs porque a renovação o passa como
  // falso (capítulo 27); o resto das chamadas usa o padrão.
  void answer(String path, Object? Function() response) => when(
    () => api.post(
      path,
      body: any(named: 'body'),
      authenticated: any(named: 'authenticated'),
    ),
  ).thenAnswer((_) async => response());

  void refuse(String path, ApiError error) => when(
    () => api.post(
      path,
      body: any(named: 'body'),
      authenticated: any(named: 'authenticated'),
    ),
  ).thenThrow(error);

  setUp(() {
    api = _MockApiClient();
    databases = FfiLocalDatabaseFactory();
    cleaners = DefaultLogoutCleanerRegistry();
    outboxes = DefaultOutboxRegistry();
    logger = FakeLogger();
    analytics = FakeAnalytics();
    tasks = _TasksCleaner();
    cleaners.register(tasks);
    outboxes.register(_TasksOutbox());
    startApp();
  });

  tearDown(() async {
    while (getIt.hasScope('app')) {
      await getIt.popScope();
    }
  });

  group('pela tela', () {
    /// O botão continua ocupado depois do sucesso, com o indicador
    /// animando: pumpAndSettle nunca terminaria.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> openLogin(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/auth/login',
        routes: authModuleRoutes,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('pt'),
          localizationsDelegates:
              AuthModuleLocalizations.localizationsDelegates,
          supportedLocales: AuthModuleLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    Future<void> signInWith(WidgetTester tester, String email) async {
      await tester.enterText(find.widgetWithText(TextField, 'E-mail'), email);
      await tester.enterText(
        find.widgetWithText(TextField, 'Senha'),
        _password,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await settle(tester);
    }

    testWidgets('o login guarda a sessão e entrega o token ao core', (
      tester,
    ) async {
      answer(AuthApiPaths.signIn, () => _signInResponse);
      await openLogin(tester);

      await signInWith(tester, ' Ana@Exemplo.com ');

      verify(
        () => api.post(
          AuthApiPaths.signIn,
          body: {'email': 'ana@exemplo.com', 'password': _password},
        ),
      ).called(1);
      expect(await token(), 'eyJhbGciOiJIUzI1NiJ9.acesso');
      expect(logger.userIds, ['u-1']);
      expect(analytics.events, ['auth_session_started']);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('credenciais recusadas: a mensagem certa e nenhuma sessão', (
      tester,
    ) async {
      refuse(
        AuthApiPaths.signIn,
        const ApiError(
          ApiErrorKind.rejected,
          statusCode: 401,
          body: {'code': 'invalid_credentials'},
        ),
      );
      await openLogin(tester);

      await signInWith(tester, 'ana@exemplo.com');

      expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
      expect(await token(), isNull);
      expect(analytics.events, isEmpty);
    });

    testWidgets('sem rede: a mensagem genérica, e tentar de novo funciona', (
      tester,
    ) async {
      refuse(AuthApiPaths.signIn, const ApiError(ApiErrorKind.unreachable));
      await openLogin(tester);

      await signInWith(tester, 'ana@exemplo.com');
      expect(
        find.text('Não foi possível entrar agora. Tente de novo.'),
        findsOneWidget,
      );

      answer(AuthApiPaths.signIn, () => _signInResponse);
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await settle(tester);

      expect(await token(), 'eyJhbGciOiJIUzI1NiJ9.acesso');
    });

    testWidgets('o cadastro, aberto pelo login, cria a conta e a sessão', (
      tester,
    ) async {
      answer(AuthApiPaths.register, () => _signInResponse);
      await openLogin(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Criar uma conta'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Nome'), ' Ana ');
      await tester.enterText(
        find.widgetWithText(TextField, 'E-mail'),
        'ana@exemplo.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Senha (pelo menos 15 caracteres)'),
        _password,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
      await settle(tester);

      verify(
        () => api.post(
          AuthApiPaths.register,
          body: {
            'name': 'Ana',
            'email': 'ana@exemplo.com',
            'password': _password,
          },
        ),
      ).called(1);
      expect(await token(), 'eyJhbGciOiJIUzI1NiJ9.acesso');
      expect(analytics.events, ['auth_account_registered']);
    });

    testWidgets('uma senha curta é recusada no aparelho, sem ir à rede', (
      tester,
    ) async {
      await openLogin(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Criar uma conta'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Ana');
      await tester.enterText(
        find.widgetWithText(TextField, 'E-mail'),
        'ana@exemplo.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Senha (pelo menos 15 caracteres)'),
        'curta',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
      await settle(tester);

      expect(
        find.text(
          'Escolha outra senha: pelo menos 15 caracteres, '
          'e que não seja uma senha conhecida.',
        ),
        findsOneWidget,
      );
      verifyZeroInteractions(api);
    });
  });

  group('pelo caso de uso', () {
    Future<void> signedIn() async {
      answer(AuthApiPaths.signIn, () => _signInResponse);
      await auth().signInWithPassword(
        email: 'ana@exemplo.com',
        password: _password,
      );
      clearInteractions(api);
    }

    test('a sessão volta depois de reabrir o app, sem rede', () async {
      await signedIn();

      await restartApp();
      final user = await auth().restoreSession();

      expect(user?.id, 'u-1');
      expect(await token(), 'eyJhbGciOiJIUzI1NiJ9.acesso');
      verifyZeroInteractions(api);
      expect(logger.userIds, ['u-1', 'u-1']);
      expect(analytics.events, ['auth_session_started']);
    });

    test(
      'o logout conta as pendências de outros módulos e apaga tudo',
      () async {
        await signedIn();
        when(
          () => api.post(AuthApiPaths.signOut),
        ).thenAnswer((_) async => null);

        expect(await auth().pendingChanges(), 2);
        await auth().signOut();

        verify(() => api.post(AuthApiPaths.signOut)).called(1);
        expect(await token(), isNull);
        expect(tasks.cleared, 1);
        expect(logger.userIds.last, isNull);
        expect(analytics.events.last, 'auth_session_ended');

        await restartApp();
        expect(await auth().restoreSession(), isNull);
      },
    );

    test(
      'sem rede, o logout apaga os dados locais e avisa quem chamou',
      () async {
        await signedIn();
        when(
          () => api.post(AuthApiPaths.signOut),
        ).thenThrow(const ApiError(ApiErrorKind.unreachable));

        await expectLater(auth().signOut(), throwsA(isA<ApiError>()));

        expect(await token(), isNull);
        expect(tasks.cleared, 1);
        expect(analytics.events, isNot(contains('auth_session_ended')));
      },
    );

    test(
      'a renovação grava o par novo, que sobrevive a reabrir o app',
      () async {
        await signedIn();
        answer(
          AuthApiPaths.refresh,
          () => {'accessToken': 'at-2', 'refreshToken': 'rt-2'},
        );

        expect(await getIt<TokenProvider>().refreshToken(), 'at-2');
        verify(
          () => api.post(
            AuthApiPaths.refresh,
            body: {'refreshToken': 'rt-1'},
            authenticated: false,
          ),
        ).called(1);

        await restartApp();
        expect(await token(), 'at-2');
      },
    );

    test('renovação sem rede: o erro sobe e a sessão continua', () async {
      await signedIn();
      refuse(AuthApiPaths.refresh, const ApiError(ApiErrorKind.unreachable));

      await expectLater(
        getIt<TokenProvider>().refreshToken(),
        throwsA(isA<ApiError>()),
      );
      expect(await token(), 'eyJhbGciOiJIUzI1NiJ9.acesso');
    });

    test('renovação recusada: a sessão expira e o fim limpa todos os '
        'módulos', () async {
      await signedIn();
      refuse(
        AuthApiPaths.refresh,
        const ApiError(ApiErrorKind.rejected, statusCode: 401),
      );
      final expired = auth().watchSessionExpired().first;

      expect(await getIt<TokenProvider>().refreshToken(), isNull);
      await expired;
      expect(await token(), isNull);

      await auth().endExpiredSession();
      expect(tasks.cleared, 1);
      expect(logger.userIds.last, isNull);
      expect(analytics.events.last, 'auth_session_expired');
    });
  });

  group('pelo estado da sessão, como o host vê', () {
    late SessionBloc session;
    late List<SessionState> states;

    void watchSession() {
      session = getIt<SessionBloc>();
      states = [];
      session.stream.listen(states.add);
    }

    test('o login abre a sessão; o logout a fecha depois da limpeza', () async {
      final spy = _SessionSpy();
      cleaners.register(spy);
      watchSession();
      answer(AuthApiPaths.signIn, () => _signInResponse);
      when(() => api.post(AuthApiPaths.signOut)).thenAnswer((_) async => null);

      await auth().signInWithPassword(
        email: 'ana@exemplo.com',
        password: _password,
      );
      await pumpEventQueue();
      expect(states, [isA<SessionAuthenticated>()]);

      await auth().signOut();
      await pumpEventQueue();
      expect(spy.seen, isA<SessionAuthenticated>());
      expect(states.last, isA<SessionUnauthenticated>());
    });

    test(
      'reaberto o app, a restauração devolve a sessão sem ir à rede',
      () async {
        answer(AuthApiPaths.signIn, () => _signInResponse);
        await auth().signInWithPassword(
          email: 'ana@exemplo.com',
          password: _password,
        );
        clearInteractions(api);

        await restartApp();
        watchSession();
        session.add(const SessionRestoreRequested());
        await pumpEventQueue();

        expect(states, [isA<SessionAuthenticated>()]);
        verifyZeroInteractions(api);
      },
    );

    test('sem sessão guardada, a restauração diz que ninguém entrou', () async {
      watchSession();
      session.add(const SessionRestoreRequested());
      await pumpEventQueue();

      expect(states, [isA<SessionUnauthenticated>()]);
    });

    /// A sessão de Ana cai no servidor: a renovação é recusada.
    Future<void> expireSession() async {
      refuse(
        AuthApiPaths.refresh,
        const ApiError(ApiErrorKind.rejected, statusCode: 401),
      );
      expect(await getIt<TokenProvider>().refreshToken(), isNull);
      await pumpEventQueue();
    }

    Future<void> signInAs(Object? response, String email) async {
      answer(AuthApiPaths.signIn, () => response);
      await auth().signInWithPassword(email: email, password: _password);
      await pumpEventQueue();
    }

    test('renovação recusada com alterações pendentes: a sessão espera a '
        'decisão, e nada é apagado', () async {
      watchSession();
      await signInAs(_signInResponse, 'ana@exemplo.com');

      await expireSession();

      expect(
        states.last,
        isA<SessionExpiredWithPendingChanges>().having(
          (state) => state.pendingChanges,
          'pendingChanges',
          2,
        ),
      );
      expect(await token(), isNull);
      expect(tasks.cleared, 0);

      session.add(const SessionDiscardRequested());
      await pumpEventQueue();

      expect(states.last, isA<SessionUnauthenticated>());
      expect(tasks.cleared, 1);
      expect(analytics.events.last, 'auth_session_expired');
    });

    test(
      'sem alterações pendentes, a sessão expirada termina sozinha',
      () async {
        outboxes.unregisterAll();
        watchSession();
        await signInAs(_signInResponse, 'ana@exemplo.com');

        await expireSession();

        expect(states.last, isA<SessionUnauthenticated>());
        expect(tasks.cleared, 1);
      },
    );

    test('depois da expiração, a mesma pessoa entra e encontra tudo', () async {
      watchSession();
      await signInAs(_signInResponse, 'ana@exemplo.com');
      await expireSession();

      await signInAs(_signInResponse, 'ana@exemplo.com');

      expect(states.last, isA<SessionAuthenticated>());
      expect(tasks.cleared, 0);
    });

    test('depois da expiração, outra pessoa entra: os dados da anterior são '
        'apagados antes', () async {
      final spy = _SessionSpy();
      watchSession();
      await signInAs(_signInResponse, 'ana@exemplo.com');
      await expireSession();
      cleaners.register(spy);

      final bia = {
        ..._signInResponse as Map<String, Object?>,
        'user': {'id': 'u-2', 'name': 'Bia', 'email': 'bia@exemplo.com'},
      };
      await signInAs(bia, 'bia@exemplo.com');

      expect(tasks.cleared, 1);
      expect(spy.seen, isA<SessionExpiredWithPendingChanges>());
      expect(states.last, isA<SessionAuthenticated>());
      expect(logger.userIds, ['u-1', 'u-2']);
    });

    group('depois da expiração e de reabrir o app (capítulo 32)', () {
      final bia = {
        ..._signInResponse as Map<String, Object?>,
        'user': {'id': 'u-2', 'name': 'Bia', 'email': 'bia@exemplo.com'},
      };

      /// Ana sai por expiração com alterações pendentes, e o app é fechado
      /// antes de alguém decidir. A memória some; o banco fica.
      Future<void> expiredAndRestarted() async {
        watchSession();
        await signInAs(_signInResponse, 'ana@exemplo.com');
        await expireSession();
        await restartApp();
        watchSession();
        session.add(const SessionRestoreRequested());
        await pumpEventQueue();
      }

      test('o boot volta a esperar a decisão, com as pendências contadas, e '
          'nada é apagado', () async {
        await expiredAndRestarted();

        expect(states, [
          isA<SessionExpiredWithPendingChanges>().having(
            (state) => state.pendingChanges,
            'pendingChanges',
            2,
          ),
        ]);
        expect(tasks.cleared, 0);
      });

      test('outra pessoa entra: os dados da anterior são apagados antes de a '
          'nova sessão ser publicada', () async {
        await expiredAndRestarted();
        final spy = _SessionSpy();
        cleaners.register(spy);

        await signInAs(bia, 'bia@exemplo.com');

        expect(tasks.cleared, 1);
        expect(spy.seen, isA<SessionExpiredWithPendingChanges>());
        expect(states.last, isA<SessionAuthenticated>());
      });

      test('a mesma pessoa entra e encontra tudo', () async {
        await expiredAndRestarted();

        await signInAs(_signInResponse, 'ana@exemplo.com');

        expect(tasks.cleared, 0);
        expect(states.last, isA<SessionAuthenticated>());
      });

      test('descartar apaga os dados e o dono: o boot seguinte começa sem '
          'ninguém', () async {
        await expiredAndRestarted();
        session.add(const SessionDiscardRequested());
        await pumpEventQueue();
        expect(tasks.cleared, 1);

        await restartApp();
        watchSession();
        session.add(const SessionRestoreRequested());
        await pumpEventQueue();

        expect(states, [isA<SessionUnauthenticated>()]);
      });
    });
  });
}
