import '../../../domain/entities/task.dart';
import '../../../domain/entities/task_conflict.dart';
import '../models/task_model.dart';

/// O que o repositório pede ao banco do aparelho. Uma linha que o domínio
/// recusa chega como `LocalDatabaseError`: o dado foi gravado pelo próprio
/// app, e o usuário não tem como corrigi-lo (capítulo 9).
abstract interface class TaskLocalService {
  Stream<List<Task>> watchActiveTasks();
  Future<Task?> findTask(String taskId);

  /// Grava a tarefa e, na mesma transação, a operação que o backend
  /// precisa receber (capítulo 31).
  Future<void> saveTask(Task task);
  Future<void> archiveTask(String taskId);

  /// Troca a cópia local pela lista do backend, menos as tarefas com
  /// operação pendente na fila ou recusa aberta, e guarda a hora da
  /// atualização.
  Future<void> saveActiveTasks(
    List<TaskModel> tasks, {
    required DateTime refreshedAt,
  });

  /// `null` enquanto a lista nunca veio do backend neste aparelho.
  Future<DateTime?> lastRefreshedAt();

  Future<bool> showCompletedTasks();
  Future<void> saveShowCompletedTasks(bool show);

  /// Apaga as tarefas, a fila, as recusas, o estado da atualização e as
  /// preferências do usuário: o logout (capítulo 29).
  Future<void> deleteAll();

  /// As recusas abertas com a tarefa como está no aparelho, das mais
  /// antigas para as mais novas (capítulo 34).
  Stream<List<TaskConflict>> watchConflicts();

  /// "Manter a minha": numa transação, o conflito e as operações pendentes
  /// da tarefa saem, e uma operação nova leva o estado do aparelho ao
  /// servidor, apoiada na versão que ele tem agora. Sem versão no servidor
  /// (a tarefa foi apagada lá), a operação é uma criação.
  Future<void> keepLocalVersion(
    String conflictId, {
    required String taskId,
    required int? serverVersion,
  });

  /// "Manter a do servidor" e "Refazer": o conflito e as operações
  /// pendentes saem, e a tarefa passa a ser a do servidor; sem ela, sai do
  /// aparelho.
  Future<void> acceptServerVersion(
    String conflictId, {
    required String taskId,
    required TaskModel? server,
  });

  /// "Descartar": o conflito e as operações pendentes saem, e a lista fica
  /// vencida, para que a próxima atualização traga o estado real. Sem rede.
  Future<void> discardConflict(String conflictId, {required String taskId});
}
