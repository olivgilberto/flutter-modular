import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tasks_module/adapters/driving/bloc/task_edit_bloc.dart';
import 'package:tasks_module/adapters/driving/l10n/tasks_module_localizations.dart';
import 'package:tasks_module/adapters/driving/views/task_edit_view.dart';
import 'package:tasks_module/domain/task_failure.dart';

import '../../support/text_scale.dart';
import 'driving_mocks.dart';

void main() {
  late MockTaskEditBloc bloc;
  late StreamController<TaskEditState> states;

  setUpAll(() => registerFallbackValue(const TaskEditArchived()));

  setUp(() {
    bloc = MockTaskEditBloc();
    states = StreamController<TaskEditState>();
  });
  // Sem await: um StreamController que ninguém escutou nunca termina de
  // fechar.
  tearDown(() => unawaited(states.close()));

  /// A tela de edição empilhada sobre uma tela de origem, como na lista.
  Future<void> show(WidgetTester tester, TaskEditState state) async {
    whenListen(bloc, states.stream, initialState: state);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Text('origem'),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, _) => BlocProvider<TaskEditBloc>.value(
                value: bloc,
                child: const TaskEditView(),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('pt'),
        localizationsDelegates: TasksModuleLocalizations.localizationsDelegates,
        supportedLocales: TasksModuleLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    unawaited(router.push('/edit'));
    // Sem pumpAndSettle: carregando e gravando, o indicador gira sem fim.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('carregando, o indicador', (tester) async {
    await show(tester, const TaskEditLoading());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a tarefa que saiu da lista', (tester) async {
    await show(tester, const TaskEditNotFound());
    expect(find.text('Esta tarefa não está mais na lista'), findsOneWidget);
  });

  testWidgets('o campo começa com o título, uma vez só', (tester) async {
    await show(tester, const TaskEditLoading());

    states.add(TaskEditReady(bread));
    await tester.pump();
    await tester.pump();
    expect(fieldText(tester), 'Comprar pão');

    await tester.enterText(find.byType(TextField), 'Comprar pão integral');
    states.add(TaskEditReady(bread));
    await tester.pump();
    await tester.pump();
    expect(fieldText(tester), 'Comprar pão integral');
  });

  testWidgets('salvar envia o texto cru, pelo botão ou pelo teclado', (
    tester,
  ) async {
    await show(tester, TaskEditReady(bread));

    await tester.enterText(find.byType(TextField), ' Outro ');
    await tester.tap(find.text('Salvar'));
    await tester.testTextInput.receiveAction(TextInputAction.done);

    final submitted = verify(
      () => bloc.add(captureAny(that: isA<TaskEditSubmitted>())),
    ).captured.cast<TaskEditSubmitted>();
    expect([for (final e in submitted) e.title], [' Outro ', ' Outro ']);
  });

  testWidgets('arquivar pede confirmação', (tester) async {
    await show(tester, TaskEditReady(bread));

    await tester.tap(find.text('Arquivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    verifyNever(() => bloc.add(any(that: isA<TaskEditArchived>())));

    await tester.tap(find.text('Arquivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arquivar').last);
    await tester.pumpAndSettle();
    verify(() => bloc.add(any(that: isA<TaskEditArchived>()))).called(1);
  });

  for (final (state, message) in [
    (
      TaskEditReady(bread, failure: const EmptyTaskTitleFailure()),
      'Escreva um título para a tarefa.',
    ),
    (
      TaskEditReady(bread, failure: const TaskTitleTooLongFailure()),
      'O título passou do tamanho máximo.',
    ),
    (
      TaskEditReady(bread, failure: const TaskNotFoundFailure()),
      'Esta tarefa não está mais na lista.',
    ),
    (
      TaskEditReady(bread, unavailable: true),
      'Algo deu errado. Tente de novo.',
    ),
  ]) {
    testWidgets('mostra "$message"', (tester) async {
      await show(tester, state);
      expect(find.text(message), findsOneWidget);
    });
  }

  testWidgets('gravando, os botões esperam', (tester) async {
    await show(tester, TaskEditSaving(bread));

    final archive = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Arquivar'),
        matching: find.byType(TextButton),
      ),
    );
    expect(archive.onPressed, isNull);
  });

  testWidgets('guardada, a tela fecha', (tester) async {
    await show(tester, TaskEditReady(bread));

    states.add(const TaskEditDone());
    await tester.pumpAndSettle();

    expect(find.text('origem'), findsOneWidget);
  });

  // Capítulo 39: a fonte do sistema aumentada, num telefone pequeno. Um
  // transbordamento é um erro do Flutter, que o takeException devolve; o
  // estado escolhido é o que mais escreve na tela.
  group('com a fonte do sistema aumentada', () {
    for (final scale in systemTextScales) {
      testWidgets('em ${scale}x, nada transborda e "Salvar" e "Arquivar" se '
          'alcançam', (tester) async {
        useSmallPhone(tester, textScale: scale);
        await show(tester, const TaskEditLoading());
        states.add(TaskEditReady(bread));
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        await expectReachable(tester, find.text('Salvar'));
        await expectReachable(tester, find.text('Arquivar'));
      });
    }
  });
}
