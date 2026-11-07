import 'task_operation.dart';

/// A fila de envio, do ponto de vista de quem envia. Interna ao módulo: só
/// o `TaskSyncableOutbox` a usa, e o `SqliteTaskService` a implementa no
/// mesmo banco das tarefas.
abstract interface class TaskOutboxQueue {
  /// As operações na ordem em que foram gravadas.
  Future<List<TaskOperation>> pendingInOrder();

  Future<int> pendingCount();

  /// O servidor aceitou a operação e respondeu a versão nova da tarefa. Numa
  /// transação: a operação sai da fila, a tarefa guarda a versão, e as
  /// operações seguintes da mesma tarefa, feitas sobre o resultado desta,
  /// passam a ter essa versão como base. Uma operação que já saiu, porque o
  /// outro isolate a enviou, não muda nada.
  Future<void> complete(TaskOperation operation, {required int newVersion});

  /// Tira a operação da fila sem tocar na tarefa: o que ela queria já
  /// tinha acontecido.
  Future<void> remove(String operationId);
}
