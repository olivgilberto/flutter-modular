import 'package:auth_module/adapters/driving/bloc/login_bloc.dart';
import 'package:auth_module/adapters/driving/l10n/auth_module_localizations.dart';
import 'package:auth_module/adapters/driving/session/session_bloc.dart';
import 'package:auth_module/adapters/driving/views/login_view.dart';
import 'package:auth_module/domain/auth_failure.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/text_scale.dart';
import 'driving_mocks.dart';

void main() {
  late MockLoginBloc bloc;

  setUpAll(
    () => registerFallbackValue(const LoginSubmitted(email: '', password: '')),
  );

  setUp(() => bloc = MockLoginBloc());

  /// A View recebe um Bloc simulado num estado fixo: sem get_it, sem caso
  /// de uso, sem rede.
  Future<void> show(
    WidgetTester tester,
    LoginState state, {
    SessionExpiredWithPendingChanges? expiredSession,
    VoidCallback? onDiscard,
  }) async {
    whenListen(bloc, const Stream<LoginState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('pt'),
        localizationsDelegates: AuthModuleLocalizations.localizationsDelegates,
        supportedLocales: AuthModuleLocalizations.supportedLocales,
        home: BlocProvider<LoginBloc>.value(
          value: bloc,
          child: LoginView(
            expiredSession: expiredSession,
            onDiscard: onDiscard,
          ),
        ),
      ),
    );
  }

  for (final (state, message) in [
    (
      const LoginSubmitFailure(InvalidCredentialsFailure()),
      'E-mail ou senha incorretos.',
    ),
    (
      const LoginSubmitFailure(WeakPasswordFailure()),
      'E-mail ou senha incorretos.',
    ),
    (
      const LoginSubmitFailure(InvalidEmailFailure()),
      'Confira o e-mail digitado.',
    ),
    (
      const LoginSubmitFailure.unavailable(),
      'Não foi possível entrar agora. Tente de novo.',
    ),
  ]) {
    testWidgets('mostra "$message" para ${state.failure.runtimeType}', (
      tester,
    ) async {
      await show(tester, state);

      expect(find.text(message), findsOneWidget);
      // Tentar de novo é tocar em "Entrar" outra vez.
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });
  }

  testWidgets('durante o envio, os botões ficam desabilitados', (tester) async {
    await show(tester, const LoginSubmitInProgress());

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
  });

  testWidgets('"Entrar" envia o texto como foi digitado', (tester) async {
    await show(tester, const LoginInitial());

    await tester.enterText(
      find.widgetWithText(TextField, 'E-mail'),
      ' Ana@Exemplo.com ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Senha'),
      strongPassword,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));

    final event =
        verify(() => bloc.add(captureAny())).captured.single as LoginSubmitted;
    expect(event.email, ' Ana@Exemplo.com ');
    expect(event.password, strongPassword);
  });

  group('depois de uma sessão expirada com alterações não enviadas', () {
    testWidgets('a tela avisa quantas são e oferece descartá-las', (
      tester,
    ) async {
      await show(
        tester,
        const LoginInitial(),
        expiredSession: const SessionExpiredWithPendingChanges(
          pendingChanges: 2,
        ),
      );

      expect(
        find.text(
          'Sua sessão expirou, e há 2 alterações ainda não enviadas. Entre '
          'de novo para enviar o que falta, ou descarte.',
        ),
        findsOneWidget,
      );
      expect(find.text('Descartar alterações'), findsOneWidget);
    });

    testWidgets('descartar só acontece depois da confirmação', (tester) async {
      var discarded = 0;
      await show(
        tester,
        const LoginInitial(),
        expiredSession: const SessionExpiredWithPendingChanges(
          pendingChanges: null,
        ),
        onDiscard: () => discarded++,
      );
      expect(
        find.textContaining('pode haver alterações ainda não enviadas'),
        findsOneWidget,
      );

      await tester.tap(find.text('Descartar alterações'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(discarded, 0);

      await tester.tap(find.text('Descartar alterações'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(discarded, 1);
    });

    testWidgets('sem sessão expirada, nada de aviso', (tester) async {
      await show(tester, const LoginInitial());

      expect(find.text('Descartar alterações'), findsNothing);
    });
  });

  // Capítulo 39: a fonte do sistema aumentada, num telefone pequeno. Um
  // transbordamento é um erro do Flutter, que o takeException devolve; o
  // estado escolhido é o que mais escreve na tela.
  group('com a fonte do sistema aumentada', () {
    for (final scale in systemTextScales) {
      testWidgets('em ${scale}x, nada transborda e "Entrar" se alcança', (
        tester,
      ) async {
        useSmallPhone(tester, textScale: scale);
        await show(
          tester,
          const LoginSubmitFailure.unavailable(),
          expiredSession: const SessionExpiredWithPendingChanges(
            pendingChanges: 2,
          ),
        );

        expect(tester.takeException(), isNull);
        await expectReachable(tester, find.text('Entrar'));
        await expectReachable(tester, find.text('Criar uma conta'));
      });
    }
  });
}
