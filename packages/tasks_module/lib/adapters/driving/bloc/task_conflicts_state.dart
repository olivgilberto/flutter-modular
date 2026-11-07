part of 'task_conflicts_bloc.dart';

/// A versão do servidor de um conflito, como a tela a conhece.
sealed class ServerVersion {
  const ServerVersion();
}

final class ServerVersionLoading extends ServerVersion {
  const ServerVersionLoading();
}

/// A versão atual do servidor, ou `null` quando a tarefa foi apagada lá.
final class ServerVersionFound extends ServerVersion {
  const ServerVersionFound(this.task);

  final Task? task;
}

/// Sem rede: a comparação espera, e "Descartar" continua possível.
final class ServerVersionUnavailable extends ServerVersion {
  const ServerVersionUnavailable();
}

enum TaskConflictsNotice { offline, unavailable }

/// O estado nunca sobrescreve o `==`: cada emissão chega à tela.
final class TaskConflictsState {
  const TaskConflictsState({
    this.loading = true,
    this.conflicts = const [],
    this.servers = const {},
    this.resolving,
    this.redoTaskId,
    this.notice,
  });

  final bool loading;
  final List<TaskConflict> conflicts;

  /// A versão do servidor de cada conflito, pelo id do conflito.
  final Map<String, ServerVersion> servers;

  /// O conflito cuja decisão está sendo aplicada.
  final String? resolving;

  /// Uma vez só: a tarefa que a tela abre depois de "Refazer".
  final String? redoTaskId;
  final TaskConflictsNotice? notice;

  TaskConflictsState withServer(String conflictId, ServerVersion server) =>
      copyWith(servers: {...servers, conflictId: server});

  /// Cada cópia esquece a decisão em andamento, a navegação e o aviso, a
  /// não ser que traga outros.
  TaskConflictsState copyWith({
    bool? loading,
    List<TaskConflict>? conflicts,
    Map<String, ServerVersion>? servers,
    String? resolving,
    String? redoTaskId,
    TaskConflictsNotice? notice,
  }) => TaskConflictsState(
    loading: loading ?? this.loading,
    conflicts: conflicts ?? this.conflicts,
    servers: servers ?? this.servers,
    resolving: resolving,
    redoTaskId: redoTaskId,
    notice: notice,
  );
}
