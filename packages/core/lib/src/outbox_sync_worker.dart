import 'app_logger.dart';
import 'local_database.dart';
import 'outbox.dart';

/// Roda todas as filas inscritas no [OutboxRegistry], cada uma isolada das
/// outras. Não sabe nada de tarefas, endpoints ou tabelas.
final class OutboxSyncWorker {
  OutboxSyncWorker({
    required OutboxRegistry registry,
    required AppLogger logger,
  }) : _registry = registry,
       _logger = logger;

  final OutboxRegistry _registry;
  final AppLogger _logger;

  /// True quando alguma fila deixou algo para a próxima rodada.
  ///
  /// Um [LocalDatabaseError] numa fila é registrado e conta como "tentar
  /// de novo", sem impedir as outras. Cada fila já trata os `ApiError` no
  /// próprio envio. Um bug continua sendo um `Error`: o `Future.wait`
  /// espera as outras filas terminarem e só então o relança.
  Future<bool> run() async {
    final retries = await Future.wait([
      for (final outbox in _registry.outboxes.toList()) _runOne(outbox),
    ]);
    return retries.contains(true);
  }

  Future<bool> _runOne(SyncableOutbox outbox) async {
    try {
      return await outbox.sync();
    } on LocalDatabaseError catch (error, stackTrace) {
      _logger.error('outbox ${outbox.name}', error, stackTrace);
      return true;
    }
  }
}
