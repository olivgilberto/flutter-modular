import 'package:core/core.dart';

/// Os desvios de negócio das tarefas: tudo o que o usuário pode corrigir.
/// Nenhuma falha carrega texto; a View decide a mensagem.
sealed class TaskFailure implements Failure {
  const TaskFailure();
}

/// O título ficou vazio depois de tirados os espaços das pontas.
final class EmptyTaskTitleFailure extends TaskFailure {
  const EmptyTaskTitleFailure();
}

/// O título passa do limite combinado com o backend (`TaskTitle.maxLength`).
final class TaskTitleTooLongFailure extends TaskFailure {
  const TaskTitleTooLongFailure();
}

/// A tarefa não está mais na lista deste aparelho, como depois de
/// arquivada em outra tela.
final class TaskNotFoundFailure extends TaskFailure {
  const TaskNotFoundFailure();
}
