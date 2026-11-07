# core

As portas do projeto e o código que não depende de nenhuma tecnologia.

- **Contém:** interfaces (`abstract interface class`) que mais de um pacote
  usa, os tipos de erro compartilhados (`Failure`, `ApiError`,
  `LocalDatabaseError`) e implementações que só trabalham com portas
  (registries, `OutboxSyncWorker`, `DefaultConnectivityService`,
  `SyncOrchestrator`).
- **Nunca contém:** dependências (nem Flutter), regras de negócio de um
  módulo, implementações de tecnologia (essas ficam nos pacotes
  `adapter_*`).

O `pubspec.yaml` não tem a seção `dependencies`, e o `check-deps` do
workspace falha se ela aparecer.
