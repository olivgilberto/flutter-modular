part of 'task_edit_bloc.dart';

/// Os estados nunca sobrescrevem o `==`: cada emissão chega à tela.
sealed class TaskEditState {
  const TaskEditState();
}

final class TaskEditLoading extends TaskEditState {
  const TaskEditLoading();
}

/// A tarefa saiu da lista, aqui ou em outra tela.
final class TaskEditNotFound extends TaskEditState {
  const TaskEditNotFound();
}

final class TaskEditReady extends TaskEditState {
  const TaskEditReady(this.task, {this.failure, this.unavailable = false});

  final Task task;

  /// A última tentativa recusada pelo domínio, se houve.
  final TaskFailure? failure;

  /// A última tentativa falhou no banco do aparelho.
  final bool unavailable;
}

final class TaskEditSaving extends TaskEditState {
  const TaskEditSaving(this.task);

  final Task task;
}

/// Guardado no aparelho: a tela fecha. O envio acontece por trás.
final class TaskEditDone extends TaskEditState {
  const TaskEditDone();
}
