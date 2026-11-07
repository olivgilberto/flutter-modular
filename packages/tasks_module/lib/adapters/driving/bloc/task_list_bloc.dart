import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../application/use_cases/task_use_case.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/task_conflict.dart';
import '../../../domain/task_failure.dart';

part 'task_list_event.dart';
part 'task_list_state.dart';

/// O ViewModel da lista de tarefas. Depende só do caso de uso. Nenhum
/// evento consulta a conexão: escrever funciona sempre, e só o gesto de
/// atualizar pode falhar por falta de rede (capítulo 33).
///
/// Não é `final`: os testes da View o simulam com `implements`.
class TaskListBloc extends Bloc<TaskListEvent, TaskListState> {
  TaskListBloc({required TaskUseCase tasks})
    : _tasks = tasks,
      super(const TaskListState()) {
    // Começar de novo, depois de uma falha, troca as assinaturas antigas.
    on<TaskListStarted>(_onStarted, transformer: restartable());
    // Na ordem em que o usuário digitou.
    on<TaskCreated>(_onCreated, transformer: sequential());
    on<TaskToggled>(_onToggled);
    on<TaskListRefreshed>(_onRefreshed, transformer: droppable());
    on<ShowCompletedToggled>(
      _onShowCompletedToggled,
      transformer: sequential(),
    );
  }

  final TaskUseCase _tasks;

  Future<void> _onStarted(
    TaskListStarted event,
    Emitter<TaskListState> emit,
  ) async {
    emit(state.copyWith(status: TaskListStatus.loading));
    try {
      emit(state.copyWith(showCompleted: await _tasks.showCompletedTasks()));
    } on LocalDatabaseError {
      // Sem a preferência, as concluídas aparecem, como no primeiro uso.
    }
    await Future.wait([
      emit.forEach<List<Task>>(
        _tasks.watchActiveTasks(),
        onData: (tasks) =>
            state.copyWith(status: TaskListStatus.ready, tasks: tasks),
        onError: (error, stackTrace) => _technical(error)
            ? state.copyWith(status: TaskListStatus.failure)
            : Error.throwWithStackTrace(error, stackTrace),
      ),
      emit.forEach<List<TaskConflict>>(
        _tasks.watchConflicts(),
        onData: (conflicts) => state.copyWith(conflicts: conflicts.length),
        // Sem a contagem, a lista continua; o aviso volta na próxima vez.
        onError: (error, stackTrace) => _technical(error)
            ? state
            : Error.throwWithStackTrace(error, stackTrace),
      ),
    ]);
  }

  Future<void> _onCreated(TaskCreated event, Emitter<TaskListState> emit) =>
      _attempt(emit, () async {
        await _tasks.createTask(title: event.title);
        emit(state.copyWith(notice: TaskListNotice.created));
      });

  Future<void> _onToggled(TaskToggled event, Emitter<TaskListState> emit) =>
      _attempt(
        emit,
        () => event.task.isDone
            ? _tasks.reopenTask(event.task.id)
            : _tasks.completeTask(event.task.id),
      );

  Future<void> _onRefreshed(
    TaskListRefreshed event,
    Emitter<TaskListState> emit,
  ) async {
    emit(state.copyWith(refreshing: true));
    try {
      await _tasks.refreshTasks();
      emit(state.copyWith(refreshing: false));
    } on ApiError {
      emit(
        state.copyWith(refreshing: false, notice: TaskListNotice.refreshFailed),
      );
    } on LocalDatabaseError {
      emit(
        state.copyWith(refreshing: false, notice: TaskListNotice.unavailable),
      );
    }
  }

  Future<void> _onShowCompletedToggled(
    ShowCompletedToggled event,
    Emitter<TaskListState> emit,
  ) async {
    final show = !state.showCompleted;
    emit(state.copyWith(showCompleted: show));
    try {
      await _tasks.setShowCompletedTasks(show);
    } on LocalDatabaseError {
      emit(state.copyWith(notice: TaskListNotice.unavailable));
    }
  }

  /// As falhas que o usuário entende viram aviso; as técnicas, um aviso
  /// genérico. Um bug continua sendo um bug.
  Future<void> _attempt(
    Emitter<TaskListState> emit,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on TaskFailure catch (failure) {
      emit(state.copyWith(notice: TaskListNotice.of(failure)));
    } on LocalDatabaseError {
      emit(state.copyWith(notice: TaskListNotice.unavailable));
    }
  }

  static bool _technical(Object error) =>
      error is ApiError || error is LocalDatabaseError;
}
