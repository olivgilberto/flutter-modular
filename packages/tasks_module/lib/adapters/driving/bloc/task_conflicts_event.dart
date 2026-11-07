part of 'task_conflicts_bloc.dart';

sealed class TaskConflictsEvent {
  const TaskConflictsEvent();
}

final class TaskConflictsStarted extends TaskConflictsEvent {
  const TaskConflictsStarted();
}

/// Buscar, ou buscar de novo, a versão do servidor de um conflito.
final class ServerVersionRequested extends TaskConflictsEvent {
  const ServerVersionRequested(this.conflict);

  final TaskConflict conflict;
}

final class TaskConflictResolved extends TaskConflictsEvent {
  const TaskConflictResolved(this.conflict, this.choice);

  final TaskConflict conflict;
  final TaskConflictChoice choice;
}
