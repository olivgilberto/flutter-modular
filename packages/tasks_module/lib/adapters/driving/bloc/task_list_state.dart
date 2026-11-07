part of 'task_list_bloc.dart';

enum TaskListStatus { loading, ready, failure }

/// Um aviso de uma vez só, que a View mostra e esquece. A falha não carrega
/// texto: a View escolhe a mensagem.
enum TaskListNotice {
  created,
  emptyTitle,
  titleTooLong,
  notFound,
  refreshFailed,
  unavailable;

  static TaskListNotice of(TaskFailure failure) => switch (failure) {
    EmptyTaskTitleFailure() => emptyTitle,
    TaskTitleTooLongFailure() => titleTooLong,
    TaskNotFoundFailure() => notFound,
  };
}

/// O estado nunca sobrescreve o `==`: cada emissão chega à tela.
final class TaskListState {
  const TaskListState({
    this.status = TaskListStatus.loading,
    this.tasks = const [],
    this.conflicts = 0,
    this.showCompleted = true,
    this.refreshing = false,
    this.notice,
  });

  final TaskListStatus status;

  /// Todas as tarefas não arquivadas, como o banco as entrega.
  final List<Task> tasks;

  /// Quantas alterações esperam a decisão do usuário (capítulo 34).
  final int conflicts;
  final bool showCompleted;
  final bool refreshing;
  final TaskListNotice? notice;

  /// O que a tela mostra, segundo a preferência do usuário.
  List<Task> get visibleTasks => showCompleted
      ? tasks
      : [
          for (final task in tasks)
            if (!task.isDone) task,
        ];

  /// Cada cópia esquece o aviso anterior, a não ser que traga outro.
  TaskListState copyWith({
    TaskListStatus? status,
    List<Task>? tasks,
    int? conflicts,
    bool? showCompleted,
    bool? refreshing,
    TaskListNotice? notice,
  }) => TaskListState(
    status: status ?? this.status,
    tasks: tasks ?? this.tasks,
    conflicts: conflicts ?? this.conflicts,
    showCompleted: showCompleted ?? this.showCompleted,
    refreshing: refreshing ?? this.refreshing,
    notice: notice,
  );
}
