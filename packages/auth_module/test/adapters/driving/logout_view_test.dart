import 'dart:async';

import 'package:auth_module/adapters/driving/bloc/logout_bloc.dart';
import 'package:auth_module/adapters/driving/l10n/auth_module_localizations.dart';
import 'package:auth_module/adapters/driving/views/logout_view.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/text_scale.dart';
import 'driving_mocks.dart';

void main() {
  late MockLogoutBloc bloc;
  late StreamController<LogoutState> states;

  setUpAll(() => registerFallbackValue(const LogoutRequested()));

  setUp(() {
    bloc = MockLogoutBloc();
    states = StreamController<LogoutState>();
    whenListen(bloc, states.stream, initialState: const LogoutInitial());
  });

  Future<void> show(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('pt'),
      localizationsDelegates: AuthModuleLocalizations.localizationsDelegates,
      supportedLocales: AuthModuleLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider<LogoutBloc>.value(
          value: bloc,
          child: const LogoutView(),
        ),
      ),
    ),
  );

  Future<void> emit(WidgetTester tester, LogoutState state) async {
    states.add(state);
    await tester.pumpAndSettle();
  }

  testWidgets('o toque em "Sair" pede a verificação', (tester) async {
    await show(tester);

    await tester.tap(find.text('Sair'));

    verify(() => bloc.add(const LogoutRequested())).called(1);
  });

  testWidgets('sem nada pendente, sai sem perguntar', (tester) async {
    await show(tester);

    await emit(tester, const LogoutCheckSuccess(pendingChanges: 0));

    expect(find.byType(AlertDialog), findsNothing);
    verify(() => bloc.add(const LogoutConfirmed())).called(1);
  });

  testWidgets('com alterações pendentes, só sai se o usuário confirmar', (
    tester,
  ) async {
    await show(tester);

    await emit(tester, const LogoutCheckSuccess(pendingChanges: 2));
    expect(
      find.text(
        '2 alterações feitas sem conexão ainda não foram enviadas e serão '
        'perdidas.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    verifyNever(() => bloc.add(const LogoutConfirmed()));

    await emit(tester, const LogoutCheckSuccess(pendingChanges: 1));
    expect(
      find.text(
        '1 alteração feita sem conexão ainda não foi enviada e será perdida.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Sair mesmo assim'));
    await tester.pumpAndSettle();
    verify(() => bloc.add(const LogoutConfirmed())).called(1);
  });

  testWidgets('sem conseguir contar, também pergunta', (tester) async {
    await show(tester);

    await emit(tester, const LogoutCheckFailure());

    expect(find.byType(AlertDialog), findsOneWidget);
    verifyNever(() => bloc.add(const LogoutConfirmed()));
  });

  // Capítulo 39: a fonte do sistema aumentada, num telefone pequeno. Um
  // transbordamento é um erro do Flutter, que o takeException devolve; o
  // estado escolhido é o que mais escreve na tela.
  group('com a fonte do sistema aumentada', () {
    for (final scale in systemTextScales) {
      testWidgets('em ${scale}x, a confirmação cabe e "Sair mesmo assim" se '
          'alcança', (tester) async {
        useSmallPhone(tester, textScale: scale);
        await show(tester);
        await emit(tester, const LogoutCheckSuccess(pendingChanges: 2));

        expect(tester.takeException(), isNull);
        await expectReachable(tester, find.text('Sair mesmo assim'));
        await expectReachable(tester, find.text('Cancelar'));
      });
    }
  });
}
