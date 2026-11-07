import 'dart:async';

import 'package:core/core.dart';

import '../../domain/entities/task.dart';
import '../../domain/entities/task_conflict.dart';
import '../../domain/task_failure.dart';
import '../../domain/value_objects/task_title.dart';
import '../ports/task_repository.dart';

/// A porta driving das tarefas: um caso de uso para a feature inteira.
/// Recebe texto cru da tela e só entrega à porta tarefas válidas.
///
/// Cada operação que deu certo registra um evento de produto no padrão
/// `tasks_[objeto]_[ação]` (capítulos 14 e 38), sem esperar por ele: uma
/// falha da métrica nunca faz a operação parecer falha. Nenhum evento leva
/// o título nem o id da tarefa.
///
/// Não é `final`: os testes dos Blocs vão simulá-lo com `implements`.
class TaskUseCase {
  TaskUseCase({
    required TaskRepository repository,
    required String Function() newId,
    required DateTime Function() now,
    required AppAnalytics analytics,
  }) : _repository = repository,
       _newId = newId,
       _now = now,
       _analytics = analytics;

  final TaskRepository _repository;
  final AppAnalytics _analytics;
  final String Function() _newId;
  final DateTime Function() _now;

  Stream<List<Task>> watchActiveTasks() => _repository.watchActiveTasks();

  /// O gesto de puxar para atualizar. Sem rede, o `ApiError` chega à tela,
  /// e a lista do aparelho continua onde estava.
  Future<void> refreshTasks() => _repository.refreshActiveTasks();

  /// `async` para que uma falha de validação chegue como erro do `Future`,
  /// e não como exceção síncrona antes de ele existir.
  Future<Task> createTask({required String title}) async {
    final task = Task(
      id: _newId(),
      title: TaskTitle.parse(title),
      createdAt: _now(),
    );
    await _repository.saveTask(task);
    _event('tasks_task_created');
    return task;
  }

  Future<void> renameTask(String taskId, {required String title}) async {
    final newTitle = TaskTitle.parse(title);
    final task = await _taskInList(taskId);
    await _repository.saveTask(task.rename(newTitle));
    _event('tasks_task_renamed');
  }

  Future<void> completeTask(String taskId) async {
    final task = await _taskInList(taskId);
    await _repository.saveTask(task.complete());
    _event('tasks_task_completed');
  }

  Future<void> reopenTask(String taskId) async {
    final task = await _taskInList(taskId);
    await _repository.saveTask(task.reopen());
    _event('tasks_task_reopened');
  }

  Future<void> archiveTask(String taskId) async {
    await _taskInList(taskId);
    await _repository.archiveTask(taskId);
    _event('tasks_task_archived');
  }

  /// A tarefa como está no aparelho, para a tela de edição; `null` quando
  /// ela já saiu da lista.
  Future<Task?> findTask(String taskId) async {
    final task = await _repository.findTask(taskId);
    return task == null || task.isArchived ? null : task;
  }

  Future<bool> showCompletedTasks() => _repository.showCompletedTasks();

  Future<void> setShowCompletedTasks(bool show) =>
      _repository.saveShowCompletedTasks(show);

  /// As alterações que esperam a decisão do usuário (capítulo 34).
  Stream<List<TaskConflict>> watchConflicts() => _repository.watchConflicts();

  /// A versão do servidor, para o usuário comparar com a dele.
  Future<Task?> serverVersion(TaskConflict conflict) =>
      _repository.fetchServerTask(conflict.task.id);

  /// Uma decisão que não faz sentido para o motivo do conflito é defeito de
  /// quem chamou, e não do usuário.
  Future<void> resolveConflict(
    TaskConflict conflict,
    TaskConflictChoice choice,
  ) async {
    if (!conflict.choices.contains(choice)) {
      throw ArgumentError.value(choice, 'choice', 'não serve a este conflito');
    }
    await _repository.resolveConflict(conflict, choice);
    _event('tasks_conflict_resolved', {
      'reason': conflict.reason.name,
      'choice': choice.name,
    });
  }

  void _event(String name, [Map<String, Object> parameters = const {}]) =>
      unawaited(_analytics.logEvent(name, parameters));

  /// Uma tarefa arquivada já saiu da lista: para quem a vê, ela não existe.
  Future<Task> _taskInList(String taskId) async {
    final task = await _repository.findTask(taskId);
    if (task == null || task.isArchived) throw const TaskNotFoundFailure();
    return task;
  }
}
