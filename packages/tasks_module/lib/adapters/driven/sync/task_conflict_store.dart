import 'task_operation.dart';

/// Por que o servidor recusou uma operação.
enum TaskConflictKind {
  /// 409 de versão: alguém mudou a tarefa antes.
  conflict,

  /// Outra recusa 4xx: a operação nunca vai passar como está.
  rejected,
}

/// As recusas guardadas em `sync_conflicts`, à espera do usuário
/// (capítulo 34). Interna ao módulo, como a fila.
abstract interface class TaskConflictStore {
  /// As tarefas com uma recusa aberta: as operações seguintes delas
  /// esperam na fila.
  Future<Set<String>> entitiesWithOpenConflict();

  Future<int> openConflictCount();

  /// Numa transação: a operação sai da fila e vira uma recusa. Uma segunda
  /// cópia da mesma operação é ignorada.
  Future<void> moveFromQueue(
    TaskOperation operation, {
    required TaskConflictKind kind,
    required int statusCode,
  });
}
