import '../../domain/entities/task.dart';
import '../../domain/entities/task_conflict.dart';

/// A porta driven das tarefas. O banco do aparelho responde na hora, e o
/// backend o atualiza em segundo plano (capítulo 31).
abstract interface class TaskRepository {
  /// As tarefas não arquivadas, das mais novas para as mais antigas. Emite
  /// a lista atual e, de novo, depois de cada mudança, inclusive as que
  /// chegam do backend. Sem nenhuma lista guardada, a primeira vem da rede,
  /// e uma falha dela chega como erro do `Stream`.
  Stream<List<Task>> watchActiveTasks();

  /// Busca a lista no backend agora. Uma falha chega a quem chamou.
  Future<void> refreshActiveTasks();

  /// `null` quando a tarefa não existe neste aparelho.
  Future<Task?> findTask(String taskId);

  /// Grava uma tarefa nova ou a versão nova de uma existente.
  Future<void> saveTask(Task task);

  Future<void> archiveTask(String taskId);

  /// Se a lista mostra as tarefas concluídas. É uma preferência do
  /// usuário, guardada com as tarefas dele, e não do aparelho.
  Future<bool> showCompletedTasks();
  Future<void> saveShowCompletedTasks(bool show);

  /// As alterações que o servidor não aceitou, das mais antigas para as
  /// mais novas, de novo a cada mudança (capítulo 34).
  Stream<List<TaskConflict>> watchConflicts();

  /// A versão da tarefa no servidor agora, ou `null` quando ela não existe
  /// mais lá. Vai à rede: uma falha chega como `ApiError`.
  Future<Task?> fetchServerTask(String taskId);

  /// Aplica a decisão do usuário e tira o conflito da espera. `keepMine`,
  /// `keepServer` e `redo` vão ao servidor buscar o estado atual; `discard`
  /// funciona sem rede.
  Future<void> resolveConflict(
    TaskConflict conflict,
    TaskConflictChoice choice,
  );
}
