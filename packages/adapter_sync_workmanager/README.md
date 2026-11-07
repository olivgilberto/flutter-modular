# adapter_sync_workmanager

A sincronização das filas com o app fechado, com workmanager.

- **Contém:** `WorkmanagerSyncScheduler` (porta `SyncScheduler`) e
  `runWorkmanagerSyncTask`, que o ponto de entrada em segundo plano do host
  chama para não importar o workmanager.
- **Nunca contém:** o que sincronizar (é o `OutboxSyncWorker` do core) nem
  a configuração de plataforma (Info.plist e AppDelegate ficam no host).
