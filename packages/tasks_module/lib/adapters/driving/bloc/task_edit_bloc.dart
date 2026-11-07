import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../application/use_cases/task_use_case.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/task_failure.dart';

part 'task_edit_event.dart';
part 'task_edit_state.dart';

/// O ViewModel da tela de uma tarefa: renomear e arquivar. É também o
/// destino de "Refazer" na tela de conflitos (capítulo 34).
///
/// Não é `final`: os testes da View o simulam com `implements`.
class TaskEditBloc extends Bloc<TaskEditEvent, TaskEditState> {
  TaskEditBloc({required TaskUseCase tasks})
    : _tasks = tasks,
      super(const TaskEditLoading()) {
    on<TaskEditStarted>(_onStarted);
    // Uma gravação por vez: toques repetidos são ignorados.
    on<TaskEditSubmitted>(_onSubmitted, transformer: droppable());
    on<TaskEditArchived>(_onArchived, transformer: droppable());
  }

  final TaskUseCase _tasks;

  Future<void> _onStarted(
    TaskEditStarted event,
    Emitter<TaskEditState> emit,
  ) async {
    try {
      final task = await _tasks.findTask(event.taskId);
      emit(task == null ? const TaskEditNotFound() : TaskEditReady(task));
    } on LocalDatabaseError {
      emit(const TaskEditNotFound());
    }
  }

  Future<void> _onSubmitted(
    TaskEditSubmitted event,
    Emitter<TaskEditState> emit,
  ) => _save(emit, (task) => _tasks.renameTask(task.id, title: event.title));

  Future<void> _onArchived(
    TaskEditArchived event,
    Emitter<TaskEditState> emit,
  ) => _save(emit, (task) => _tasks.archiveTask(task.id));

  Future<void> _save(
    Emitter<TaskEditState> emit,
    Future<void> Function(Task task) action,
  ) async {
    final current = state;
    if (current is! TaskEditReady) return;
    emit(TaskEditSaving(current.task));
    try {
      await action(current.task);
      emit(const TaskEditDone());
    } on TaskNotFoundFailure {
      emit(const TaskEditNotFound());
    } on TaskFailure catch (failure) {
      emit(TaskEditReady(current.task, failure: failure));
    } on LocalDatabaseError {
      emit(TaskEditReady(current.task, unavailable: true));
    }
  }
}
