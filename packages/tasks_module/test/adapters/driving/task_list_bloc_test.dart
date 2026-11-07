import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tasks_module/adapters/driving/bloc/task_list_bloc.dart';
import 'package:tasks_module/domain/task_failure.dart';

import 'driving_mocks.dart';

void main() {
  late MockTaskUseCase tasks;

  setUp(() {
    tasks = MockTaskUseCase();
    when(() => tasks.showCompletedTasks()).thenAnswer((_) async => true);
    when(
      () => tasks.watchActiveTasks(),
    ).thenAnswer((_) => Stream.value([bread, light]));
    when(() => tasks.watchConflicts()).thenAnswer((_) => Stream.value([]));
  });

  /// Um Bloc já iniciado, com a lista carregada.
  Future<TaskListBloc> started() async {
    final bloc = TaskListBloc(tasks: tasks)..add(const TaskListStarted());
    addTearDown(bloc.close);
    await pumpEventQueue();
    return bloc;
  }

  test('começa carregando', () {
    final bloc = TaskListBloc(tasks: tasks);
    addTearDown(bloc.close);
    expect(bloc.state.status, TaskListStatus.loading);
  });

  test('a lista do banco, a preferência e a contagem de conflitos chegam '
      'ao estado', () async {
    when(() => tasks.showCompletedTasks()).thenAnswer((_) async => false);
    when(() => tasks.watchConflicts()).thenAnswer(
      (_) => Stream.value([conflictOf(bread), conflictOf(light, id: 'c-2')]),
    );

    final bloc = await started();

    expect(bloc.state.status, TaskListStatus.ready);
    expect(bloc.state.tasks, [bread, light]);
    expect(bloc.state.conflicts, 2);
    expect(bloc.state.showCompleted, isFalse);
    expect(bloc.state.visibleTasks, [bread]);
  });

  test('sem a preferência guardada, as concluídas aparecem', () async {
    when(
      () => tasks.showCompletedTasks(),
    ).thenThrow(const LocalDatabaseError('travado'));

    final bloc = await started();

    expect(bloc.state.showCompleted, isTrue);
    expect(bloc.state.visibleTasks, [bread, light]);
  });

  for (final error in [
    const ApiError(ApiErrorKind.unreachable),
    const LocalDatabaseError('travado'),
  ]) {
    test('a primeira carga que falha (${error.runtimeType}) vira falha, e '
        'tentar de novo carrega', () async {
      when(
        () => tasks.watchActiveTasks(),
      ).thenAnswer((_) => Stream.error(error));
      final bloc = await started();
      expect(bloc.state.status, TaskListStatus.failure);

      when(
        () => tasks.watchActiveTasks(),
      ).thenAnswer((_) => Stream.value([bread]));
      bloc.add(const TaskListStarted());
      await pumpEventQueue();

      expect(bloc.state.status, TaskListStatus.ready);
      expect(bloc.state.tasks, [bread]);
    });
  }

  test('sem a contagem de conflitos, a lista continua', () async {
    when(
      () => tasks.watchConflicts(),
    ).thenAnswer((_) => Stream.error(const LocalDatabaseError('travado')));

    final bloc = await started();

    expect(bloc.state.status, TaskListStatus.ready);
    expect(bloc.state.conflicts, 0);
  });

  group('criar', () {
    test('guardada, o aviso pede para limpar o campo', () async {
      when(
        () => tasks.createTask(title: any(named: 'title')),
      ).thenAnswer((_) async => bread);
      final bloc = await started();

      bloc.add(const TaskCreated('Comprar pão'));
      await pumpEventQueue();

      verify(() => tasks.createTask(title: 'Comprar pão')).called(1);
      expect(bloc.state.notice, TaskListNotice.created);
    });

    for (final (thrown, notice) in [
      (const EmptyTaskTitleFailure(), TaskListNotice.emptyTitle),
      (const TaskTitleTooLongFailure(), TaskListNotice.titleTooLong),
      (const TaskNotFoundFailure(), TaskListNotice.notFound),
      (const LocalDatabaseError('travado'), TaskListNotice.unavailable),
    ]) {
      test('${thrown.runtimeType} vira o aviso ${notice.name}', () async {
        when(
          () => tasks.createTask(title: any(named: 'title')),
        ).thenThrow(thrown);
        final bloc = await started();

        bloc.add(const TaskCreated(''));
        await pumpEventQueue();

        expect(bloc.state.notice, notice);
      });
    }
  });

  test('marcar conclui a aberta e reabre a concluída', () async {
    when(() => tasks.completeTask(any())).thenAnswer((_) async {});
    when(() => tasks.reopenTask(any())).thenAnswer((_) async {});
    final bloc = await started();

    bloc
      ..add(TaskToggled(bread))
      ..add(TaskToggled(light));
    await pumpEventQueue();

    verify(() => tasks.completeTask('t-1')).called(1);
    verify(() => tasks.reopenTask('t-2')).called(1);
  });

  group('atualizar', () {
    test('marca o andamento e o fim', () async {
      final network = Completer<void>();
      when(() => tasks.refreshTasks()).thenAnswer((_) => network.future);
      final bloc = await started();

      bloc.add(const TaskListRefreshed());
      await pumpEventQueue();
      expect(bloc.state.refreshing, isTrue);

      network.complete();
      await pumpEventQueue();
      expect(bloc.state.refreshing, isFalse);
      expect(bloc.state.notice, isNull);
    });

    test('um segundo gesto durante o primeiro é ignorado', () async {
      final network = Completer<void>();
      when(() => tasks.refreshTasks()).thenAnswer((_) => network.future);
      final bloc = await started();

      bloc
        ..add(const TaskListRefreshed())
        ..add(const TaskListRefreshed());
      await pumpEventQueue();
      network.complete();
      await pumpEventQueue();

      verify(() => tasks.refreshTasks()).called(1);
    });

    for (final (thrown, notice) in [
      (const ApiError(ApiErrorKind.unreachable), TaskListNotice.refreshFailed),
      (const LocalDatabaseError('travado'), TaskListNotice.unavailable),
    ]) {
      test('${thrown.runtimeType} vira o aviso ${notice.name}, e a lista '
          'fica', () async {
        when(() => tasks.refreshTasks()).thenThrow(thrown);
        final bloc = await started();

        bloc.add(const TaskListRefreshed());
        await pumpEventQueue();

        expect(bloc.state.refreshing, isFalse);
        expect(bloc.state.notice, notice);
        expect(bloc.state.tasks, [bread, light]);
      });
    }
  });

  group('mostrar concluídas', () {
    test('troca na hora e guarda a escolha', () async {
      when(() => tasks.setShowCompletedTasks(any())).thenAnswer((_) async {});
      final bloc = await started();

      bloc.add(const ShowCompletedToggled());
      await pumpEventQueue();

      expect(bloc.state.showCompleted, isFalse);
      expect(bloc.state.visibleTasks, [bread]);
      verify(() => tasks.setShowCompletedTasks(false)).called(1);
    });

    test('sem conseguir guardar, a troca vale até fechar, com aviso', () async {
      when(
        () => tasks.setShowCompletedTasks(any()),
      ).thenThrow(const LocalDatabaseError('travado'));
      final bloc = await started();

      bloc.add(const ShowCompletedToggled());
      await pumpEventQueue();

      expect(bloc.state.showCompleted, isFalse);
      expect(bloc.state.notice, TaskListNotice.unavailable);
    });
  });

  test('cada cópia do estado esquece o aviso anterior', () {
    const state = TaskListState(notice: TaskListNotice.created);
    expect(state.copyWith(refreshing: true).notice, isNull);
  });
}
