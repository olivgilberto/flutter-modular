import '../task_failure.dart';

/// O título de uma tarefa, que só existe se não for vazio nem longo demais.
final class TaskTitle {
  const TaskTitle._(this.value);

  /// Remove os espaços das pontas. O tamanho é contado em pontos de código,
  /// a mesma conta do backend: um emoji composto pode valer mais de um.
  factory TaskTitle.parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) throw const EmptyTaskTitleFailure();
    if (trimmed.runes.length > maxLength) {
      throw const TaskTitleTooLongFailure();
    }
    return TaskTitle._(trimmed);
  }

  /// Combinado com o backend.
  static const maxLength = 200;

  final String value;

  @override
  bool operator ==(Object other) => other is TaskTitle && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
