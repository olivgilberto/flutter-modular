import 'package:core/core.dart';

import '../../../domain/task_failure.dart';
import '../models/task_model.dart';
import '../task_api_paths.dart';
import 'task_remote_service.dart';

/// As tarefas do backend REST, página por página, pelo cursor que cada
/// resposta devolve.
final class RestTaskService implements TaskRemoteService {
  RestTaskService({required ApiClient apiClient, this.pageSize = 100})
    : _api = apiClient;

  final ApiClient _api;

  /// Quantas tarefas por página o app pede.
  final int pageSize;

  @override
  Future<List<TaskModel>> fetchActiveTasks() async {
    final tasks = <TaskModel>[];
    final seen = <String>{};
    String? cursor;
    do {
      final page = _readPage(
        await _api.get(
          TaskApiPaths.tasks,
          query: {'status': 'active', 'limit': '$pageSize', 'cursor': ?cursor},
        ),
      );
      tasks.addAll(page.items);
      cursor = page.nextCursor;
      // Um cursor repetido faria o laço girar para sempre.
      if (cursor != null && !seen.add(cursor)) {
        throw const ApiError(ApiErrorKind.invalidResponse);
      }
    } while (cursor != null);
    return tasks;
  }

  /// `GET` de uma tarefa. O 404 é uma resposta, não uma falha: a tarefa foi
  /// apagada no servidor, e a tela de conflitos precisa saber disso.
  @override
  Future<TaskModel?> fetchTask(String taskId) async {
    final Object? json;
    try {
      json = await _api.get(TaskApiPaths.task(taskId));
    } on ApiError catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
    return _readTask(json);
  }

  static TaskModel _readTask(Object? json) {
    try {
      final model = TaskModel.fromJson(json);
      model.toEntity();
      return model;
    } on FormatException {
      throw const ApiError(ApiErrorKind.invalidResponse);
    } on TaskFailure {
      throw const ApiError(ApiErrorKind.invalidResponse);
    }
  }

  /// Cada item é validado aqui, pelo domínio: uma tarefa que ele recusa não
  /// chega ao banco do aparelho.
  static ({List<TaskModel> items, String? nextCursor}) _readPage(Object? json) {
    if (json case {'items': List<Object?> items, 'nextCursor': String? next}) {
      try {
        final models = [for (final item in items) TaskModel.fromJson(item)];
        for (final model in models) {
          model.toEntity();
        }
        return (items: models, nextCursor: next);
      } on FormatException {
        throw const ApiError(ApiErrorKind.invalidResponse);
      } on TaskFailure {
        throw const ApiError(ApiErrorKind.invalidResponse);
      }
    }
    throw const ApiError(ApiErrorKind.invalidResponse);
  }
}
