import 'package:bloc_test/bloc_test.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tasks_module/adapters/driving/bloc/task_conflicts_bloc.dart';
import 'package:tasks_module/adapters/driving/bloc/task_edit_bloc.dart';
import 'package:tasks_module/adapters/driving/bloc/task_list_bloc.dart';
import 'package:tasks_module/tasks_module.dart';

import 'driving_mocks.dart';

void main() {
  late MockTaskListBloc list;
  late MockTaskEditBloc edit;
  late MockTaskConflictsBloc conflicts;

  setUpAll(() {
    registerFallbackValue(const TaskListStarted());
    registerFallbackValue(const TaskEditArchived());
    registerFallbackValue(const TaskConflictsStarted());
  });

  // As Pages são o único ponto do lado driving que consulta o get_it: os
  // Blocs simulados entram no lugar das fábricas do módulo.
  setUp(() {
    list = MockTaskListBloc();
    edit = MockTaskEditBloc();
    conflicts = MockTaskConflictsBloc();
    whenListen(
      list,
      const Stream<TaskListState>.empty(),
      initialState: const TaskListState(),
    );
    whenListen(
      edit,
      const Stream<TaskEditState>.empty(),
      initialState: const TaskEditLoading(),
    );
    whenListen(
      conflicts,
      const Stream<TaskConflictsState>.empty(),
      initialState: const TaskConflictsState(),
    );
    GetIt.instance
      ..registerFactory<TaskListBloc>(() => list)
      ..registerFactory<TaskEditBloc>(() => edit)
      ..registerFactory<TaskConflictsBloc>(() => conflicts);
  });
  tearDown(() => GetIt.instance.reset());

  test('nomes e caminhos seguem o formato do contrato', () {
    expect(TaskRoutes.list, 'tasks.list');
    expect(TaskRoutes.listPath, '/tasks');
    expect(TaskRoutes.edit, 'tasks.edit');
    expect(TaskRoutes.editPath, '/tasks/edit/:taskId');
    expect(TaskRoutes.conflicts, 'tasks.conflicts');
    expect(TaskRoutes.conflictsPath, '/tasks/conflicts');
    expect(
      [for (final route in tasksModuleRoutes.cast<GoRoute>()) route.name],
      [TaskRoutes.list, TaskRoutes.edit, TaskRoutes.conflicts],
    );
    expect(
      () => tasksModuleRoutes.add(tasksModuleRoutes.first),
      throwsUnsupportedError,
    );
  });

  Future<void> open(WidgetTester tester, String location) async {
    final router = GoRouter(
      initialLocation: location,
      routes: tasksModuleRoutes,
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

  testWidgets('a lista pede a carga ao abrir', (tester) async {
    await open(tester, TaskRoutes.listPath);

    expect(find.text('Tarefas'), findsOneWidget);
    verify(() => list.add(any(that: isA<TaskListStarted>()))).called(1);
  });

  testWidgets('a edição abre a tarefa do caminho', (tester) async {
    await open(tester, '/tasks/edit/t-1');

    final started =
        verify(
              () => edit.add(captureAny(that: isA<TaskEditStarted>())),
            ).captured.single
            as TaskEditStarted;
    expect(started.taskId, 't-1');
  });

  testWidgets('os conflitos começam a ser observados ao abrir', (tester) async {
    await open(tester, TaskRoutes.conflictsPath);

    expect(find.text('Alterações não aceitas'), findsOneWidget);
    verify(
      () => conflicts.add(any(that: isA<TaskConflictsStarted>())),
    ).called(1);
  });
}
