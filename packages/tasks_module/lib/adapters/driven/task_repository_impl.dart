import 'dart:async';

import 'package:core/core.dart';

import '../../application/ports/task_repository.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_conflict.dart';
import 'services/task_local_service.dart';
import 'services/task_remote_service.dart';

/// O repositório das tarefas: o banco do aparelho é a fonte da tela, e o
/// backend o atualiza (stale-while-revalidate, capítulo 12). A lista do
/// aparelho aparece na hora; a da rede chega pelo mesmo `Stream` quando
/// a atualização termina. Cada escrita é guardada com a sua operação na
/// fila e, logo depois, a fila tenta subir, sem que quem escreveu espere.
final class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl({
    required TaskRemoteService remote,
    required TaskLocalService local,
    required SyncableOutbox outbox,
    required AppLogger logger,
    required DateTime Function() now,
    this.activeTasksTtl = defaultActiveTasksTtl,
  }) : _remote = remote,
       _local = local,
       _outbox = outbox,
       _logger = logger,
       _now = now;

  /// Quanto tempo a lista do aparelho vale sem ir à rede. A lista muda
  /// pelas mãos do próprio usuário, que já a vê atualizada; o que o TTL
  /// cobre é a mudança feita em outro aparelho.
  static const defaultActiveTasksTtl = Duration(minutes: 5);

  final TaskRemoteService _remote;
  final TaskLocalService _local;

  /// A porta do `core`, a mesma instância que a função de registro inscreve
  /// no `OutboxRegistry`.
  final SyncableOutbox _outbox;
  final AppLogger _logger;
  final DateTime Function() _now;
  final Duration activeTasksTtl;
  Future<void>? _refreshing;

  @override
  Stream<List<Task>> watchActiveTasks() async* {
    final refreshedAt = await _local.lastRefreshedAt();
    if (refreshedAt == null) {
      // Primeira carga: sem cache, não há o que mostrar. Um ApiError aqui
      // chega ao Bloc, que mostra o erro com a opção de tentar de novo.
      await refreshActiveTasks();
    } else if (_isStale(refreshedAt)) {
      unawaited(_refreshInBackground());
    }
    yield* _local.watchActiveTasks();
  }

  /// Vai à rede agora, dentro ou fora do prazo, como no gesto de puxar
  /// para atualizar. Quem pedir enquanto uma atualização está em andamento
  /// recebe a mesma.
  @override
  Future<void> refreshActiveTasks() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<void> _refresh() async {
    final fresh = await _remote.fetchActiveTasks();
    await _local.saveActiveTasks(fresh, refreshedAt: _now());
  }

  /// O cache continua valendo. A falha HTTP já foi registrada pelo
  /// interceptor de logging (capítulo 27); a do banco, não, e vai para o
  /// registro de falhas aqui, porque ninguém está esperando este `Future`.
  Future<void> _refreshInBackground() async {
    try {
      await refreshActiveTasks();
    } on ApiError {
      // Nada a fazer: a próxima abertura tenta de novo.
    } on LocalDatabaseError catch (error, stackTrace) {
      _logger.error('tasks refresh', error, stackTrace);
    }
  }

  /// Um relógio que voltou no tempo também conta como vencido: a hora
  /// guardada no futuro nunca venceria sozinha.
  bool _isStale(DateTime refreshedAt) {
    final age = _now().difference(refreshedAt);
    return age.isNegative || age >= activeTasksTtl;
  }

  @override
  Future<Task?> findTask(String taskId) => _local.findTask(taskId);

  /// O `Future` termina quando a alteração está guardada no aparelho; o
  /// envio acontece por trás.
  @override
  Future<void> saveTask(Task task) async {
    await _local.saveTask(task);
    _sendSoon();
  }

  @override
  Future<void> archiveTask(String taskId) async {
    await _local.archiveTask(taskId);
    _sendSoon();
  }

  @override
  Stream<List<TaskConflict>> watchConflicts() => _local.watchConflicts();

  @override
  Future<Task?> fetchServerTask(String taskId) async =>
      (await _remote.fetchTask(taskId))?.toEntity();

  /// As decisões que precisam do servidor o consultam agora, e não quando
  /// a tela abriu: entre uma coisa e outra, a tarefa pode ter mudado de novo
  /// (capítulo 34).
  @override
  Future<void> resolveConflict(
    TaskConflict conflict,
    TaskConflictChoice choice,
  ) async {
    final taskId = conflict.task.id;
    switch (choice) {
      case TaskConflictChoice.keepMine:
        final server = await _remote.fetchTask(taskId);
        await _local.keepLocalVersion(
          conflict.id,
          taskId: taskId,
          serverVersion: server?.version,
        );
        _sendSoon();
      case TaskConflictChoice.keepServer || TaskConflictChoice.redo:
        await _local.acceptServerVersion(
          conflict.id,
          taskId: taskId,
          server: await _remote.fetchTask(taskId),
        );
      case TaskConflictChoice.discard:
        await _local.discardConflict(conflict.id, taskId: taskId);
        unawaited(_refreshInBackground());
    }
  }

  /// Com rede, sobe agora; sem rede, a operação espera o próximo gatilho
  /// (capítulo 12). As falhas HTTP o envio já tratou; a do banco vai para o
  /// registro de falhas, porque ninguém espera este `Future`.
  void _sendSoon() {
    unawaited(
      _outbox.sync().then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          if (error is! LocalDatabaseError) {
            Error.throwWithStackTrace(error, stackTrace);
          }
          _logger.error('tasks outbox', error, stackTrace);
        },
      ),
    );
  }

  @override
  Future<bool> showCompletedTasks() => _local.showCompletedTasks();

  @override
  Future<void> saveShowCompletedTasks(bool show) =>
      _local.saveShowCompletedTasks(show);
}
