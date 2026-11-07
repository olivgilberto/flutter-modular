part of 'task_list_bloc.dart';

sealed class TaskListEvent {
  const TaskListEvent();
}

/// A tela abriu, ou o usuário pediu para tentar de novo depois de uma
/// falha na primeira carga.
final class TaskListStarted extends TaskListEvent {
  const TaskListStarted();
}

/// O texto cru do campo: quem valida é o caso de uso.
final class TaskCreated extends TaskListEvent {
  const TaskCreated(this.title);

  final String title;
}

/// Concluir uma tarefa aberta, ou reabrir uma concluída.
final class TaskToggled extends TaskListEvent {
  const TaskToggled(this.task);

  final Task task;
}

/// O gesto de puxar para atualizar.
final class TaskListRefreshed extends TaskListEvent {
  const TaskListRefreshed();
}

final class ShowCompletedToggled extends TaskListEvent {
  const ShowCompletedToggled();
}
