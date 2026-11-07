import 'package:get_it/get_it.dart';
import '../value_objects/task_title.dart';

/// Em que ponto está uma tarefa. Arquivar é o fim: a tarefa sai da lista.
enum TaskStatus { open, done, archived }

/// Uma tarefa do usuário. Igualdade pelo id: a mesma tarefa continua a
/// mesma depois de ganhar outro título.
final class Task {
  const Task({
    required this.id,
    required this.title,
    required this.createdAt,
    this.status = TaskStatus.open,
  });

  /// Gerado no aparelho, no momento da criação: a tarefa existe antes de
  /// chegar ao backend, e reenviar a criação não cria outra (capítulo 32).
  final String id;
  final TaskTitle title;
  final TaskStatus status;

  /// Em UTC. Ordena a lista, das mais novas para as mais antigas.
  final DateTime createdAt;

  bool get isDone => status == TaskStatus.done;
  bool get isArchived => status == TaskStatus.archived;

  Task rename(TaskTitle newTitle) => _copy(title: newTitle);
  Task complete() => _copy(status: TaskStatus.done);
  Task reopen() => _copy(status: TaskStatus.open);

  Task _copy({TaskTitle? title, TaskStatus? status}) => Task(
    id: id,
    title: title ?? this.title,
    createdAt: createdAt,
    status: status ?? this.status,
  );

  @override
  bool operator ==(Object other) => other is Task && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
