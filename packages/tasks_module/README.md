# tasks_module

As tarefas do mobile_tarefas, offline-first: o usuário cria, conclui e
arquiva tarefas com ou sem rede, e o aparelho é a primeira fonte da lista.

- **Contém:** o domínio (`Task`, `TaskTitle`, a família `TaskFailure`), a
  aplicação (a porta `TaskRepository` e o `TaskUseCase`) e o lado driven
  (capítulo 30): o banco `tasks.db`, criptografado, aberto pela porta
  `LocalDatabaseFactory`, e o `TaskClearableOnLogout`, inscrito no
  `LogoutCleanerRegistry` do `core`. Desde o capítulo 31, a leitura pelo
  backend (`RestTaskService`, stale-while-revalidate no
  `TaskRepositoryImpl`) e a fila de envio, gravada com cada escrita.
  Desde o capítulo 32, o envio (`TaskSyncableOutbox`, inscrito no
  `OutboxRegistry`) e as recusas em `sync_conflicts`. As telas chegam nos
  capítulos seguintes.
- **Nunca contém:** dependência de outro módulo ou de um pacote
  `adapter_*`, nem tecnologia que o `core` abstrai.

Documentação: `docs/modules/tasks_module.md`.
