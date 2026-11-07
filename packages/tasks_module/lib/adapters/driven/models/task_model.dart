import '../../../domain/entities/task.dart';
import '../../../domain/value_objects/task_title.dart';

/// Uma tarefa como o backend a entrega e como a tabela `tasks` a guarda.
/// Serialização escrita à mão, nos dois formatos.
final class TaskModel {
  const TaskModel({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    this.version = 0,
  });

  /// Uma tarefa criada ou alterada no aparelho. A versão do servidor não é
  /// assunto do domínio: quem grava a busca no banco (capítulo 31).
  factory TaskModel.fromEntity(Task task) => TaskModel(
    id: task.id,
    title: task.title.value,
    status: task.status.name,
    createdAt: task.createdAt.millisecondsSinceEpoch,
  );

  /// Um item da lista do backend. Chaves a mais são ignoradas; uma a menos,
  /// ou de outro tipo, é [FormatException].
  factory TaskModel.fromJson(Object? json) {
    if (json case {
      'id': String id,
      'title': String title,
      'status': String status,
      'createdAt': String createdAt,
      'version': int version,
    }) {
      final created = DateTime.tryParse(createdAt);
      if (created == null || !created.isUtc) {
        throw FormatException('Data fora do formato: $createdAt');
      }
      return TaskModel(
        id: id,
        title: title,
        status: status,
        createdAt: created.millisecondsSinceEpoch,
        version: version,
      );
    }
    throw const FormatException('Tarefa do backend fora do formato');
  }

  /// Uma linha da tabela. Uma coluna a menos, ou de outro tipo, é
  /// [FormatException].
  factory TaskModel.fromMap(Map<String, Object?> row) {
    if (row case {
      'id': String id,
      'title': String title,
      'status': String status,
      'created_at': int createdAt,
      'version': int version,
    }) {
      return TaskModel(
        id: id,
        title: title,
        status: status,
        createdAt: createdAt,
        version: version,
      );
    }
    throw const FormatException('Tarefa guardada fora do formato');
  }

  final String id;
  final String title;

  /// O nome de um [TaskStatus]: open, done ou archived.
  final String status;

  /// Milissegundos desde 1970, em UTC.
  final int createdAt;

  /// A versão que o backend deu à tarefa; 0 enquanto ela só existe no
  /// aparelho. É a base da detecção de conflitos (capítulo 34).
  final int version;

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'status': status,
    'created_at': createdAt,
    'version': version,
  };

  /// Pode lançar `TaskFailure`, para um título que o domínio recusa, e
  /// [FormatException], para uma situação desconhecida: quem chama decide o
  /// que isso significa, porque o dado veio de fora do domínio (capítulo 9).
  Task toEntity() => Task(
    id: id,
    title: TaskTitle.parse(title),
    status: _statuses[status] ?? (throw FormatException('Situação $status')),
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true),
  );

  static final _statuses = TaskStatus.values.asNameMap();
}
