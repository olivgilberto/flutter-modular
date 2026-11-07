import 'package:auth_module/adapters/driving/bloc/register_bloc.dart';
import 'package:auth_module/adapters/driving/l10n/auth_module_localizations.dart';
import 'package:auth_module/adapters/driving/views/register_view.dart';
import 'package:auth_module/domain/auth_failure.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/text_scale.dart';
import 'driving_mocks.dart';

void main() {
  for (final (state, message) in [
    (
      const RegisterSubmitFailure(EmailAlreadyRegisteredFailure()),
      'Este e-mail já tem uma conta. Volte e entre com ele.',
    ),
    (
      const RegisterSubmitFailure(WeakPasswordFailure()),
      'Escolha outra senha: pelo menos 15 caracteres, '
          'e que não seja uma senha conhecida.',
    ),
  ]) {
    testWidgets('mostra a mensagem do cadastro para '
        '${state.failure.runtimeType}', (tester) async {
      final bloc = MockRegisterBloc();
      whenListen(
        bloc,
        const Stream<RegisterState>.empty(),
        initialState: state,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('pt'),
          localizationsDelegates:
              AuthModuleLocalizations.localizationsDelegates,
          supportedLocales: AuthModuleLocalizations.supportedLocales,
          home: BlocProvider<RegisterBloc>.value(
            value: bloc,
            child: const RegisterView(),
          ),
        ),
      );

      expect(find.text(message), findsOneWidget);
    });
  }

  // Capítulo 39: a fonte do sistema aumentada, num telefone pequeno, com a
  // mensagem mais longa da tela.
  group('com a fonte do sistema aumentada', () {
    for (final scale in systemTextScales) {
      testWidgets('em ${scale}x, nada transborda e "Criar conta" se alcança', (
        tester,
      ) async {
        useSmallPhone(tester, textScale: scale);
        final bloc = MockRegisterBloc();
        whenListen(
          bloc,
          const Stream<RegisterState>.empty(),
          initialState: const RegisterSubmitFailure(WeakPasswordFailure()),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('pt'),
            localizationsDelegates:
                AuthModuleLocalizations.localizationsDelegates,
            supportedLocales: AuthModuleLocalizations.supportedLocales,
            home: BlocProvider<RegisterBloc>.value(
              value: bloc,
              child: const RegisterView(),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        await expectReachable(tester, find.text('Criar conta'));
      });
    }
  });
}
