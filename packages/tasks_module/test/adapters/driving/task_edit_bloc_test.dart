import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tasks_module/adapters/driving/bloc/task_edit_bloc.dart';
import 'package:tasks_module/domain/task_failure.dart';

import 'driving_mocks.dart';

void main() {
  late MockTaskUseCase tasks;

  setUp(() {
    tasks = MockTaskUseCase();
    when(() => tasks.findTask('t-1')).thenAnswer((_) async => bread);
    when(
      () => tasks.renameTask(any(), title: any(named: 'title')),
    ).thenAnswer((_) async {});
    when(() => tasks.archiveTask(any())).thenAnswer((_) async {});
  });

  /// O Bloc e todos os estados que ele emitiu.
  Future<(TaskEditBloc, List<TaskEditState>)> opened() async {
    final bloc = TaskEditBloc(tasks: tasks);
    addTearDown(bloc.close);
    final states = <TaskEditState>[];
    final subscription = bloc.stream.listen(states.add);
    addTearDown(subscription.cancel);
    bloc.add(const TaskEditStarted('t-1'));
    await pumpEventQueue();
    return (bloc, states);
  }

  test('começa carregando e abre a tarefa da lista', () async {
    final (bloc, _) = await opened();

    expect(bloc.state, isA<TaskEditReady>());
    expect((bloc.state as TaskEditReady).task, bread);
  });

  for (final (label, stub) in [
    ('fora da lista', () async => null),
    ('com o banco travado', () async => throw const LocalDatabaseError('x')),
  ]) {
    test('$label, a tarefa não é encontrada', () async {
      when(() => tasks.findTask('t-1')).thenAnswer((_) => stub());

      final (bloc, _) = await opened();

      expect(bloc.state, isA<TaskEditNotFound>());
    });
  }

  test('salvar renomeia com o texto cru e fecha', () async {
    final (bloc, states) = await opened();

    bloc.add(const TaskEditSubmitted('  Comprar pão integral '));
    await pumpEventQueue();

    verify(
      () => tasks.renameTask('t-1', title: '  Comprar pão integral '),
    ).called(1);
    expect(states.skip(1).map((s) => s.runtimeType), [
      TaskEditSaving,
      TaskEditDone,
    ]);
  });

  test('arquivar fecha', () async {
    final (bloc, _) = await opened();

    bloc.add(const TaskEditArchived());
    await pumpEventQueue();

    verify(() => tasks.archiveTask('t-1')).called(1);
    expect(bloc.state, isA<TaskEditDone>());
  });

  test('toques repetidos gravam uma vez só', () async {
    final saving = Completer<void>();
    when(
      () => tasks.renameTask(any(), title: any(named: 'title')),
    ).thenAnswer((_) => saving.future);
    final (bloc, _) = await opened();

    bloc
      ..add(const TaskEditSubmitted('Outro'))
      ..add(const TaskEditSubmitted('Outro'));
    await pumpEventQueue();
    saving.complete();
    await pumpEventQueue();

    verify(() => tasks.renameTask(any(), title: any(named: 'title'))).called(1);
  });

  test('o título recusado volta à tela com a falha', () async {
    when(
      () => tasks.renameTask(any(), title: any(named: 'title')),
    ).thenThrow(const EmptyTaskTitleFailure());
    final (bloc, _) = await opened();

    bloc.add(const TaskEditSubmitted('   '));
    await pumpEventQueue();

    final state = bloc.state as TaskEditReady;
    expect(state.task, bread);
    expect(state.failure, isA<EmptyTaskTitleFailure>());
  });

  test('a tarefa que saiu da lista no meio do caminho', () async {
    when(() => tasks.archiveTask(any())).thenThrow(const TaskNotFoundFailure());
    final (bloc, _) = await opened();

    bloc.add(const TaskEditArchived());
    await pumpEventQueue();

    expect(bloc.state, isA<TaskEditNotFound>());
  });

  test('o banco travado volta à tela com o aviso genérico', () async {
    when(
      () => tasks.renameTask(any(), title: any(named: 'title')),
    ).thenThrow(const LocalDatabaseError('travado'));
    final (bloc, _) = await opened();

    bloc.add(const TaskEditSubmitted('Outro'));
    await pumpEventQueue();

    final state = bloc.state as TaskEditReady;
    expect(state.unavailable, isTrue);
    expect(state.failure, isNull);
  });

  test('antes de a tarefa abrir, salvar não faz nada', () async {
    when(() => tasks.findTask('t-1')).thenAnswer((_) async => null);
    final (bloc, _) = await opened();

    bloc.add(const TaskEditSubmitted('Outro'));
    await pumpEventQueue();

    verifyNever(() => tasks.renameTask(any(), title: any(named: 'title')));
  });
}
