import 'task.dart';

/// Por que o servidor não aceitou o que o usuário fez (capítulo 12).
enum TaskConflictReason {
  /// Outra pessoa mudou a tarefa antes: há duas versões, e uma fica.
  versionConflict,

  /// O servidor recusou a alteração em si: ela nunca vai passar como está.
  rejected,
}

/// O que o usuário pode decidir diante de um conflito.
enum TaskConflictChoice {
  /// Fica a versão do aparelho, por cima da do servidor.
  keepMine,

  /// Fica a versão do servidor, e a do aparelho é descartada.
  keepServer,

  /// A alteração recusada é descartada.
  discard,

  /// A alteração recusada é descartada, e o usuário age de novo sobre o
  /// estado atual da tarefa.
  redo,
}

/// Uma alteração que o servidor não aceitou, à espera do usuário. O domínio
/// não sabe que existiu uma resposta HTTP, uma fila ou uma tabela: sabe
/// que há uma tarefa, a versão dela no aparelho e uma decisão a tomar. A
/// versão do servidor é buscada quando o usuário abre a resolução, porque
/// até lá ela pode ter mudado de novo.
final class TaskConflict {
  const TaskConflict({
    required this.id,
    required this.reason,
    required this.task,
    required this.createdAt,
  });

  final String id;
  final TaskConflictReason reason;

  /// A tarefa como está no aparelho, com o que o usuário fez.
  final Task task;

  /// Quando a recusa chegou, em UTC.
  final DateTime createdAt;

  /// As decisões que fazem sentido para o motivo.
  List<TaskConflictChoice> get choices => switch (reason) {
    TaskConflictReason.versionConflict => const [
      TaskConflictChoice.keepMine,
      TaskConflictChoice.keepServer,
    ],
    TaskConflictReason.rejected => const [
      TaskConflictChoice.redo,
      TaskConflictChoice.discard,
    ],
  };

  @override
  bool operator ==(Object other) => other is TaskConflict && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
