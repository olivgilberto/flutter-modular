/// Agenda a sincronização das filas com o app fechado (capítulo 12). A
/// implementação fica num adaptador; o ponto de entrada em segundo plano,
/// no host.
abstract interface class SyncScheduler {
  Future<void> schedulePeriodicSync();
}
