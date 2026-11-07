import 'package:auth_module/adapters/driving/bloc/login_bloc.dart';
import 'package:auth_module/adapters/driving/bloc/register_bloc.dart';
import 'package:auth_module/adapters/driving/views/login_view.dart';
import 'package:auth_module/adapters/driving/views/register_view.dart';
import 'package:auth_module/auth_module.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'driving_mocks.dart';

void main() {
  final getIt = GetIt.instance;

  // As Pages consultam o get_it; o teste faz o papel do host num escopo
  // próprio, desfeito no fim.
  setUp(
    () => getIt.pushNewScope(
      init: (scope) {
        final auth = MockAuthUseCase();
        when(
          () => auth.watchSignedIn(),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => auth.watchSessionExpired(),
        ).thenAnswer((_) => const Stream.empty());
        scope
          ..registerFactory<LoginBloc>(() => LoginBloc(auth: auth))
          ..registerFactory<RegisterBloc>(() => RegisterBloc(auth: auth))
          // A tela de login também lê o estado da sessão (capítulo 29).
          ..registerLazySingleton<SessionBloc>(
            () => SessionBloc(auth: auth),
            dispose: (bloc) => bloc.close(),
          );
      },
    ),
  );
  tearDown(() async => getIt.popScope());

  testWidgets('os nomes seguem [módulo].[tela] e os caminhos '
      '/[módulo]/[tela]', (tester) async {
    final router = GoRouter(
      initialLocation: '/auth/login',
      routes: authModuleRoutes,
    );
    addTearDown(router.dispose);

    expect(router.namedLocation(AuthRoutes.login), '/auth/login');
    expect(router.namedLocation(AuthRoutes.register), '/auth/register');
    expect(authModuleRoutes.clear, throwsUnsupportedError);
  });

  testWidgets('do login, "Criar uma conta" abre o cadastro, e voltar '
      'retorna ao login', (tester) async {
    final router = GoRouter(
      initialLocation: '/auth/login',
      routes: authModuleRoutes,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('pt'),
        localizationsDelegates: AuthModuleLocalizations.localizationsDelegates,
        supportedLocales: AuthModuleLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    expect(find.byType(LoginView), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Criar uma conta'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterView), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(LoginView), findsOneWidget);
  });
}
