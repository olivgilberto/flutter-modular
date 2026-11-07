import 'package:core/core.dart';
import 'package:workmanager/workmanager.dart';

/// Agenda a sincronização das filas como tarefa periódica do workmanager,
/// só com rede, para que as operações pendentes subam mesmo com o app
/// fechado.
///
/// [callbackDispatcher] é o ponto de entrada em segundo plano do host, uma
/// função de topo anotada com `@pragma('vm:entry-point')` que chama
/// [runWorkmanagerSyncTask].
final class WorkmanagerSyncScheduler implements SyncScheduler {
  WorkmanagerSyncScheduler({
    required void Function() callbackDispatcher,
    this.frequency = const Duration(hours: 1),
    Workmanager? workmanager,
  }) : _callbackDispatcher = callbackDispatcher,
       _workmanager = workmanager ?? Workmanager();

  /// Também o identificador do BGTaskScheduler no iOS: o Info.plist e o
  /// AppDelegate do host usam o mesmo valor.
  static const taskName = 'outbox_sync';

  /// O Android impõe um mínimo de 15 minutos.
  final Duration frequency;
  final void Function() _callbackDispatcher;
  final Workmanager _workmanager;

  @override
  Future<void> schedulePeriodicSync() async {
    await _workmanager.initialize(_callbackDispatcher);
    await _workmanager.registerPeriodicTask(
      taskName,
      taskName,
      frequency: frequency,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }
}

/// Chamada pelo ponto de entrada em segundo plano do host. Roda [sync]
/// sempre que o sistema dispara a tarefa; devolver `false` deixa o Android
/// reagendar pela sua política de espera.
void runWorkmanagerSyncTask(Future<bool> Function() sync) {
  Workmanager().executeTask((_, _) => sync());
}
