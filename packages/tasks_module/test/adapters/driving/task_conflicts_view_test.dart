import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tasks_module/adapters/driving/bloc/task_conflicts_bloc.dart';
import 'package:tasks_module/adapters/driving/l10n/tasks_module_localizations.dart';
import 'package:tasks_module/adapters/driving/routes/tasks_module_routes.dart';
import 'package:tasks_module/adapters/driving/views/task_conflicts_view.dart';
import 'package:tasks_module/domain/entities/task.dart';
import 'package:tasks_module/domain/entities/task_conflict.dart';

import '../../support/text_scale.dart';
import 'driving_mocks.dart';

void main() {
  late MockTaskConflictsBloc bloc;
  late StreamController<TaskConflictsState> states;
  final mine = conflictOf(task('t-1', 'Comprar pão integral'));
  final refused = conflictOf(
    task('t-2', 'Pagar a luz'),
    id: 'c-2',
    reason: TaskConflictReason.rejected,
  );

  setUpAll(() => registerFallbackValue(const TaskConflictsStarted()));

  setUp(() {
    bloc = MockTaskConflictsBloc();
    states = StreamController<TaskConflictsState>();
  });
  // Sem await: um StreamController que ninguém escutou nunca termina de
  // fechar.
  tearDown(() => unawaited(states.close()));

  Future<void> show(WidgetTester tester, TaskConflictsState state) async {
    whenListen(bloc, states.stream, initialState: state);
    final router = GoRouter(
      initialLocation: TaskRoutes.conflictsPath,
      routes: [
        GoRoute(
          name: TaskRoutes.conflicts,
          path: TaskRoutes.conflictsPath,
          builder: (_, _) => BlocProvider<TaskConflictsBloc>.value(
            value: bloc,
            child: const TaskConflictsView(),
          ),
        ),
        GoRoute(
          name: TaskRoutes.edit,
          path: TaskRoutes.editPath,
          builder: (_, state) =>
              Text('editar ${state.pathParameters['taskId']}'),
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

  TaskConflictsState withServers(Map<String, ServerVersion> servers) =>
      TaskConflictsState(
        loading: false,
        conflicts: [mine, refused],
        servers: servers,
      );

  TextButton button(WidgetTester tester, String label) =>
      tester.widget<TextButton>(
        find.ancestor(of: find.text(label), matching: find.byType(TextButton)),
      );

  List<TaskConflictResolved> resolved() => verify(
    () => bloc.add(captureAny(that: isA<TaskConflictResolved>())),
  ).captured.cast<TaskConflictResolved>();

  testWidgets('carregando, o indicador', (tester) async {
    await show(tester, const TaskConflictsState());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('sem conflitos, nada espera a decisão', (tester) async {
    await show(tester, const TaskConflictsState(loading: false));
    expect(find.text('Nada esperando a sua decisão'), findsOneWidget);
  });

  testWidgets('as duas versões lado a lado, com as decisões de cada '
      'motivo', (tester) async {
    await show(
      tester,
      withServers({
        'c-1': ServerVersionFound(task('t-1', 'Comprar pão francês')),
        'c-2': ServerVersionFound(
          task('t-2', 'Pagar a luz', status: TaskStatus.done),
        ),
      }),
    );

    expect(find.text('Esta tarefa mudou em outro lugar'), findsOneWidget);
    expect(find.text('O servidor recusou esta alteração'), findsOneWidget);
    expect(
      find.textContaining('No aparelho: "Comprar pão integral"'),
      findsOneWidget,
    );
    expect(
      find.textContaining('No servidor: "Comprar pão francês"'),
      findsOneWidget,
    );
    for (final label in [
      'Manter a minha',
      'Manter a do servidor',
      'Refazer',
      'Descartar',
    ]) {
      expect(button(tester, label).onPressed, isNotNull, reason: label);
    }
  });

  testWidgets('buscando a versão do servidor, só descartar está '
      'liberado', (tester) async {
    await show(tester, withServers({}));

    expect(find.text('Buscando a versão do servidor…'), findsNWidgets(2));
    expect(button(tester, 'Manter a minha').onPressed, isNull);
    expect(button(tester, 'Manter a do servidor').onPressed, isNull);
    expect(button(tester, 'Refazer').onPressed, isNull);
    expect(button(tester, 'Descartar').onPressed, isNotNull);
  });

  testWidgets('sem rede, a busca pode ser repetida', (tester) async {
    await show(
      tester,
      withServers({
        'c-1': const ServerVersionUnavailable(),
        'c-2': const ServerVersionUnavailable(),
      }),
    );

    await tester.tap(find.text('Tentar de novo').first);

    final requested =
        verify(
              () => bloc.add(captureAny(that: isA<ServerVersionRequested>())),
            ).captured.single
            as ServerVersionRequested;
    expect(requested.conflict, mine);
  });

  testWidgets('apagada no servidor: manter a minha continua possível, '
      'refazer não', (tester) async {
    await show(
      tester,
      withServers({
        'c-1': const ServerVersionFound(null),
        'c-2': const ServerVersionFound(null),
      }),
    );

    expect(
      find.text('No servidor: a tarefa não existe mais.'),
      findsNWidgets(2),
    );
    expect(button(tester, 'Manter a minha').onPressed, isNotNull);
    expect(button(tester, 'Refazer').onPressed, isNull);
  });

  testWidgets('a decisão vai ao Bloc com o conflito', (tester) async {
    await show(
      tester,
      withServers({
        'c-1': ServerVersionFound(task('t-1', 'Comprar pão francês')),
        'c-2': ServerVersionFound(task('t-2', 'Pagar a luz')),
      }),
    );

    await tester.tap(find.text('Manter a minha'));
    await tester.tap(find.text('Manter a do servidor'));
    await tester.tap(find.text('Refazer'));

    expect(
      [for (final e in resolved()) (e.conflict.id, e.choice)],
      [
        ('c-1', TaskConflictChoice.keepMine),
        ('c-1', TaskConflictChoice.keepServer),
        ('c-2', TaskConflictChoice.redo),
      ],
    );
  });

  testWidgets('descartar pede confirmação', (tester) async {
    await show(tester, withServers({}));

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    verifyNever(() => bloc.add(any(that: isA<TaskConflictResolved>())));

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar').last);
    await tester.pumpAndSettle();
    expect(resolved().single.choice, TaskConflictChoice.discard);
  });

  testWidgets('durante a decisão, os botões do conflito esperam', (
    tester,
  ) async {
    await show(
      tester,
      TaskConflictsState(
        loading: false,
        conflicts: [refused],
        servers: {'c-2': ServerVersionFound(task('t-2', 'Pagar a luz'))},
        resolving: 'c-2',
      ),
    );

    expect(button(tester, 'Refazer').onPressed, isNull);
    expect(button(tester, 'Descartar').onPressed, isNull);
  });

  testWidgets('refazer abre a tela da tarefa no lugar desta', (tester) async {
    await show(tester, withServers({}));

    states.add(withServers({}).copyWith(redoTaskId: 't-2'));
    await tester.pumpAndSettle();

    expect(find.text('editar t-2'), findsOneWidget);
  });

  for (final (notice, message) in [
    (
      TaskConflictsNotice.offline,
      'Sem conexão com o servidor. Tente quando ela voltar.',
    ),
    (TaskConflictsNotice.unavailable, 'Algo deu errado. Tente de novo.'),
  ]) {
    testWidgets('o aviso ${notice.name}', (tester) async {
      await show(tester, withServers({}));

      states.add(withServers({}).copyWith(notice: notice));
      await tester.pump();
      // O SnackBar entra no quadro seguinte ao aviso.
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.text(message), findsOneWidget);
    });
  }

  // Capítulo 39: a fonte do sistema aumentada, num telefone pequeno. Um
  // transbordamento é um erro do Flutter, que o takeException devolve; o
  // estado escolhido é o que mais escreve na tela.
  group('com a fonte do sistema aumentada', () {
    for (final scale in systemTextScales) {
      testWidgets('em ${scale}x, nada transborda e as decisões dos dois '
          'conflitos se alcançam', (tester) async {
        useSmallPhone(tester, textScale: scale);
        await show(
          tester,
          withServers({
            'c-1': ServerVersionFound(task('t-1', 'Comprar pão francês')),
            'c-2': ServerVersionFound(
              task('t-2', 'Pagar a luz', status: TaskStatus.done),
            ),
          }),
        );

        expect(tester.takeException(), isNull);
        for (final label in [
          'Manter a minha',
          'Manter a do servidor',
          'Refazer',
          'Descartar',
        ]) {
          await expectReachable(tester, find.text(label));
        }
      });
    }
  });
}
