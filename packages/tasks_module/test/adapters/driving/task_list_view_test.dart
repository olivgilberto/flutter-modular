import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tasks_module/adapters/driving/bloc/task_list_bloc.dart';
import 'package:tasks_module/adapters/driving/l10n/tasks_module_localizations.dart';
import 'package:tasks_module/adapters/driving/routes/tasks_module_routes.dart';
import 'package:tasks_module/adapters/driving/views/task_list_view.dart';

import '../../support/text_scale.dart';
import 'driving_mocks.dart';

void main() {
  late MockTaskListBloc bloc;
  late StreamController<TaskListState> states;

  setUpAll(() => registerFallbackValue(const TaskListStarted()));

  setUp(() {
    bloc = MockTaskListBloc();
    states = StreamController<TaskListState>();
  });
  // Sem await: um StreamController que ninguém escutou nunca termina de
  // fechar.
  tearDown(() => unawaited(states.close()));

  /// A View com um Bloc simulado e um roteador com as rotas vizinhas no
  /// lugar das telas de verdade.
  Future<void> show(WidgetTester tester, TaskListState state) async {
    whenListen(bloc, states.stream, initialState: state);
    final router = GoRouter(
      initialLocation: TaskRoutes.listPath,
      routes: [
        GoRoute(
          name: TaskRoutes.list,
          path: TaskRoutes.listPath,
          builder: (_, _) => BlocProvider<TaskListBloc>.value(
            value: bloc,
            child: const TaskListView(),
          ),
        ),
        GoRoute(
          name: TaskRoutes.edit,
          path: TaskRoutes.editPath,
          builder: (_, state) =>
              Text('editar ${state.pathParameters['taskId']}'),
        ),
        GoRoute(
          name: TaskRoutes.conflicts,
          path: TaskRoutes.conflictsPath,
          builder: (_, _) => const Text('conflitos'),
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
    await tester.pump();
  }

  TaskListState ready({int conflicts = 0, bool showCompleted = true}) =>
      TaskListState(
        status: TaskListStatus.ready,
        tasks: [bread, light],
        conflicts: conflicts,
        showCompleted: showCompleted,
      );

  testWidgets('mostra as tarefas, com a concluída riscada', (tester) async {
    await show(tester, ready());

    expect(find.text('Comprar pão'), findsOneWidget);
    final done = tester.widget<Text>(find.text('Pagar a luz'));
    expect(done.style?.decoration, TextDecoration.lineThrough);
    expect(find.textContaining('decisão'), findsNothing);
  });

  testWidgets('escondidas as concluídas, só as abertas aparecem', (
    tester,
  ) async {
    await show(tester, ready(showCompleted: false));

    expect(find.text('Pagar a luz'), findsNothing);
    await tester.tap(find.byTooltip('Mostrar concluídas'));
    verify(() => bloc.add(any(that: isA<ShowCompletedToggled>()))).called(1);
  });

  testWidgets('sem tarefas, o estado vazio convida a escrever a primeira', (
    tester,
  ) async {
    await show(tester, const TaskListState(status: TaskListStatus.ready));

    expect(find.text('Nenhuma tarefa por aqui'), findsOneWidget);
  });

  testWidgets('carregando, o indicador', (tester) async {
    await show(tester, const TaskListState());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a falha da primeira carga oferece tentar de novo', (
    tester,
  ) async {
    await show(tester, const TaskListState(status: TaskListStatus.failure));

    expect(find.text('Não foi possível carregar as tarefas'), findsOneWidget);
    await tester.tap(find.text('Tentar de novo'));
    verify(() => bloc.add(any(that: isA<TaskListStarted>()))).called(1);
  });

  testWidgets('criar envia o texto cru, pelo botão ou pelo teclado', (
    tester,
  ) async {
    await show(tester, ready());

    await tester.enterText(find.byType(TextField), '  Lavar o carro ');
    await tester.tap(find.byTooltip('Adicionar'));
    await tester.testTextInput.receiveAction(TextInputAction.done);

    final created = verify(
      () => bloc.add(captureAny(that: isA<TaskCreated>())),
    ).captured.cast<TaskCreated>();
    expect(
      [for (final e in created) e.title],
      ['  Lavar o carro ', '  Lavar o carro '],
    );
  });

  testWidgets('a tarefa criada limpa o campo', (tester) async {
    await show(tester, ready());
    await tester.enterText(find.byType(TextField), 'Lavar o carro');

    states.add(ready().copyWith(notice: TaskListNotice.created));
    await tester.pump();

    expect(find.text('Lavar o carro'), findsNothing);
  });

  testWidgets('marcar envia a tarefa tocada', (tester) async {
    await show(tester, ready());

    await tester.tap(find.byType(Checkbox).first);

    final toggled =
        verify(
              () => bloc.add(captureAny(that: isA<TaskToggled>())),
            ).captured.single
            as TaskToggled;
    expect(toggled.task, bread);
  });

  testWidgets('editar abre a tela da tarefa', (tester) async {
    await show(tester, ready());

    await tester.tap(find.byTooltip('Editar').first);
    await tester.pumpAndSettle();

    expect(find.text('editar t-1'), findsOneWidget);
  });

  testWidgets('com conflitos, o aviso conta e leva à tela de decisão', (
    tester,
  ) async {
    await show(tester, ready(conflicts: 2));

    expect(find.text('2 alterações precisam da sua decisão'), findsOneWidget);
    // A lista continua inteira abaixo do aviso.
    expect(find.text('Comprar pão'), findsOneWidget);
    await tester.tap(find.text('Resolver'));
    await tester.pumpAndSettle();

    expect(find.text('conflitos'), findsOneWidget);
  });

  testWidgets('um conflito, no singular', (tester) async {
    await show(tester, ready(conflicts: 1));

    expect(find.text('1 alteração precisa da sua decisão'), findsOneWidget);
  });

  for (final (notice, message) in [
    (TaskListNotice.emptyTitle, 'Escreva um título para a tarefa.'),
    (TaskListNotice.titleTooLong, 'O título passou do tamanho máximo.'),
    (TaskListNotice.notFound, 'Esta tarefa não está mais na lista.'),
    (
      TaskListNotice.refreshFailed,
      'Não foi possível atualizar agora. A lista do aparelho continua aqui.',
    ),
    (TaskListNotice.unavailable, 'Algo deu errado. Tente de novo.'),
  ]) {
    testWidgets('o aviso ${notice.name} aparece uma vez', (tester) async {
      await show(tester, ready());

      states.add(ready().copyWith(notice: notice));
      await tester.pump();
      // O SnackBar entra no quadro seguinte ao aviso.
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.text(message), findsOneWidget);
    });
  }

  testWidgets('puxar para atualizar espera o fim da atualização', (
    tester,
  ) async {
    await show(tester, ready());

    await tester.fling(find.text('Comprar pão'), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    verify(() => bloc.add(any(that: isA<TaskListRefreshed>()))).called(1);
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);

    states
      ..add(ready().copyWith(refreshing: true))
      ..add(ready());
    await tester.pumpAndSettle();

    expect(find.byType(RefreshProgressIndicator), findsNothing);
  });

  // Capítulo 39: a fonte do sistema aumentada, num telefone pequeno. Um
  // transbordamento é um erro do Flutter, que o takeException devolve; o
  // estado escolhido é o que mais escreve na tela.
  group('com a fonte do sistema aumentada', () {
    for (final scale in systemTextScales) {
      testWidgets('em ${scale}x, nada transborda, e o campo, o "Adicionar" e '
          'o aviso de conflitos se alcançam', (tester) async {
        useSmallPhone(tester, textScale: scale);
        await show(tester, ready(conflicts: 2));

        expect(tester.takeException(), isNull);
        await expectReachable(tester, find.byTooltip('Adicionar'));
        await expectReachable(tester, find.text('Resolver'));
        await expectReachable(tester, find.text('Comprar pão'));
      });
    }
  });
}
