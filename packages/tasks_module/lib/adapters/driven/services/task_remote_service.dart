import '../models/task_model.dart';

/// O que o repositório pede ao backend. Uma falha de rede, uma recusa ou
/// uma resposta fora do formato chegam como `ApiError`.
abstract interface class TaskRemoteService {
  /// Todas as tarefas não arquivadas, já validadas, lidas página por
  /// página. Só termina com a lista inteira: uma página que falha derruba
  /// a busca, e nada parcial chega ao banco.
  Future<List<TaskModel>> fetchActiveTasks();

  /// Uma tarefa como está no servidor agora, já validada, ou `null` quando
  /// ela não existe mais lá (capítulo 34).
  Future<TaskModel?> fetchTask(String taskId);
}
