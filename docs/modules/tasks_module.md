# tasks_module

## Escopo
Tarefas do usuário, offline-first: criar, renomear, concluir, reabrir e
arquivar, com ou sem rede. Capítulo 30: domínio, aplicação e o banco do
aparelho. Capítulo 31: a leitura pelo backend (stale-while-revalidate) e
a fila de envio gravada junto com cada escrita. Capítulo 32: o envio da
fila (TaskSyncableOutbox, no OutboxRegistry) e as recusas guardadas em
sync_conflicts. Capítulo 34: as telas (lista, edição e conflitos), as
rotas exportadas e a resolução das recusas.

## Arquitetura
- domain/: Task (igualdade pelo id, id gerado no aparelho, createdAt em
  UTC), TaskStatus (open, done, archived), TaskTitle (value object com
  parse: espaços das pontas removidos, 1 a 200 pontos de código) e a
  família selada TaskFailure (EmptyTaskTitleFailure,
  TaskTitleTooLongFailure, TaskNotFoundFailure). TaskConflict (capítulo
  34: id, motivo, a tarefa como está no aparelho e a hora da recusa;
  igualdade pelo id), TaskConflictReason (versionConflict, rejected) e
  TaskConflictChoice (keepMine, keepServer, discard, redo).
- application/: a porta TaskRepository e o TaskUseCase. Uma tarefa
  arquivada não está na lista: alterá-la é TaskNotFoundFailure.
  refreshTasks() é o "puxar para atualizar". findTask() devolve null para
  a arquivada. watchConflicts(), serverVersion() e resolveConflict(): uma
  decisão que não cabe ao motivo é ArgumentError (defeito de quem chamou).
- adapters/driven/: TaskRepositoryImpl (stale-while-revalidate),
  RestTaskService (backend, por cursor), SqliteTaskService (banco, fila e
  recusas), TaskModel (backend e banco), TaskClearableOnLogout e newUuidV4
  (UUID v4 com Random.secure(), para tarefas, operações e recusas).
  sync/: TaskSyncableOutbox (implementa o SyncableOutbox do core),
  TaskOperation e as interfaces internas TaskOutboxQueue e
  TaskConflictStore, que o SqliteTaskService implementa.
- adapters/driving/ (capítulo 34): TaskListBloc, TaskEditBloc e
  TaskConflictsBloc (fábricas no get_it, um Bloc novo por tela), as Pages
  (únicos pontos que consultam o get_it), as Views e as rotas
  (TaskRoutes, tasksModuleRoutes). Textos nos ARB do módulo (capítulo
  37), em adapters/driving/l10n: tasks_module_en.arb (template) e
  tasks_module_pt.arb, gerando a TasksModuleLocalizations, exportada pelo
  arquivo de entrada. A situação da tarefa vai ao ARB pelo nome do valor
  do TaskStatus, num select.

## Navegação (capítulo 34)
O módulo exporta TaskRoutes e tasksModuleRoutes (lista imutável), no
formato dos nomes do auth_module:

| Nome | Caminho | Tela |
| --- | --- | --- |
| tasks.list | /tasks | lista: criar, concluir e reabrir, mostrar concluídas, puxar para atualizar, aviso de conflitos |
| tasks.edit | /tasks/edit/:taskId | renomear e arquivar (com confirmação); fecha quando a mudança está no aparelho |
| tasks.conflicts | /tasks/conflicts | as recusas, com a versão do aparelho e a do servidor |

O host decide onde a lista entra (a tela inicial redireciona para
/tasks) e põe as rotas dentro de uma moldura própria (ShellRoute com o
botão de sair). O módulo não conhece o auth_module nem o host.

## Resolução das recusas (capítulo 34)
A versão do servidor é buscada (GET /v1/tasks/{id}; 404 é "apagada lá")
quando a tela abre e de novo no momento da decisão, porque pode ter
mudado entre uma coisa e outra. Cada decisão apaga a recusa e as
operações da tarefa que esperavam por ela, na mesma transação:

| Motivo | Decisão | O que acontece | Precisa de rede |
| --- | --- | --- | --- |
| versionConflict | Manter a minha | uma operação nova com a tarefa do aparelho, sobre a versão atual do servidor; apagada lá, volta como criação com o mesmo id; apagada lá e arquivada aqui, sai do aparelho | sim |
| versionConflict | Manter a do servidor | grava a versão do servidor; apagada lá, sai do aparelho | sim |
| rejected | Refazer | como "Manter a do servidor", e abre a tela da tarefa para o usuário agir de novo | sim |
| rejected | Descartar | a alteração sai; a lista vence e se atualiza por trás | não |

Sem rede, a tela mostra o aviso e nada muda no aparelho. A lista mostra
quantas recusas esperam, sem bloquear nada.

## Leitura (capítulo 31)
- Sem lista guardada (sync_state vazio), a primeira vem da rede antes de
  o banco ser observado; uma falha chega como erro do Stream.
- Com lista guardada e dentro do TTL (5 minutos para a lista ativa), só o
  banco responde. Vencida, ou com a hora guardada no futuro, o banco
  responde na hora e a rede atualiza por trás; uma falha de rede some
  (o interceptor já registrou), uma do banco vai ao AppLogger como
  "tasks refresh".
- Atualizações simultâneas compartilham a mesma ida à rede.
- A lista do backend substitui a do aparelho, menos as tarefas com
  operação na fila ou recusa aberta, que ficam como estão; as que não
  vieram, sem nenhuma das duas, saem do aparelho.

## Contrato com o backend
GET /v1/tasks?status=active&limit=100[&cursor=...] responde
{"items": [{"id", "title", "status", "createdAt" (ISO 8601 em UTC),
"version"}], "nextCursor": "..." | null}. O app segue o cursor até o fim
e só grava a lista inteira; uma página que falha derruba a busca; um
cursor repetido é resposta inválida. Um item que o domínio recusa é
ApiError invalidResponse.

GET /v1/tasks/{id} (capítulo 34) responde a tarefa no mesmo formato de um
item; 404 quer dizer apagada no servidor, e o RestTaskService devolve
null.

Envio (capítulo 32), todos com Idempotency-Key = id da operação:
- PUT /v1/tasks/{id} com {"title", "status", "createdAt", "operationId"}:
  cria com o id do app.
- PATCH /v1/tasks/{id} com {"title", "status", "baseVersion",
  "operationId"} (alteração) ou {"status": "archived", "baseVersion",
  "operationId"} (arquivamento).
- Sucesso responde a tarefa com "version" (a nova). O backend grava o
  operationId com a mudança e responde 200 a um reenvio da mesma
  operação já aplicada.
- 409 de versão vem com {"code": "version_conflict"}; um 409 sem esse
  código (por exemplo, a mesma chave ainda em processamento) é tratado
  como "tentar depois".

## Banco tasks.db
Aberto pela LocalDatabaseFactory: SQLCipher, chave de 256 bits no
armazenamento seguro, arquivo em Application Support/local_databases,
fora do backup (regras do host). Esquema em
lib/adapters/driven/services/tasks_database_schema.dart.
- Versão 1 (capítulo 30): tasks (id, title, status com CHECK, created_at
  em milissegundos UTC) com o índice tasks_by_status, e preferences.
- Versão 2 (capítulo 31): tasks.version (versão do servidor, 0 enquanto
  só existe no aparelho), outbox_pending_operations (id da operação,
  entity_id, operation create/update/archive com CHECK, payload JSON,
  base_version, created_at; ordem de envio pelo rowid) com o índice
  outbox_by_entity, e sync_state (key, refreshed_at). A migração põe na
  fila a criação de cada tarefa da versão 1, que nunca foi enviada.
- Versão 3 (capítulo 32): sync_conflicts (id, operation_id único,
  entity_id, kind conflict/rejected com CHECK, status_code, operation,
  payload, base_version, created_at) com o índice
  sync_conflicts_by_entity.

Regras de mudança: createStatements é sempre o esquema completo da
versão atual; toda mudança sobe a versão e acrescenta em migrations os
comandos que levam da anterior até ela (inclusive correção de dados);
uma versão que chegou a algum aparelho nunca muda. O teste
tasks_database_schema_test guarda uma cópia de cada versão publicada,
confere que a instalação nova é igual à cópia da versão atual, que cada
versão antiga chega a ela pelas migrações e que a migração 2 preserva os
dados e enche a fila.

Uma linha que o domínio recusa (título inválido, situação desconhecida)
chega como LocalDatabaseError: o dado foi gravado pelo app, não pelo
usuário (capítulo 9).

## Fila de envio
Cada escrita grava a tarefa e a operação na mesma transação: create
(payload título, situação e createdAt), update (título e situação, com a
versão que o usuário via) e archive. Depois de gravar, o repositório pede
à fila que suba, sem esperar (uma falha do banco nesse envio vai ao
AppLogger como "tasks outbox").

O TaskSyncableOutbox (capítulo 32) é inscrito no OutboxRegistry pela
função de registro, a mesma instância que o repositório aciona. sync():
um envio por vez em cada isolate; percorre a fila na ordem de gravação,
pula as tarefas com recusa aberta, e dá a cada resposta um destino:

| Resposta | Operação |
| --- | --- |
| 2xx com version | sai da fila; a tarefa guarda a versão; as operações seguintes da tarefa passam a usá-la como base |
| 2xx sem version | sai da fila; "tasks outbox response" no AppLogger |
| sem conexão, 5xx, resposta ilegível, 401, 429, 409 sem version_conflict | fica; a rodada para (sync() devolve true) |
| 404 num arquivamento | sai: o que ela queria já aconteceu |
| 409 version_conflict | sync_conflicts, kind conflict |
| outro 4xx | sync_conflicts, kind rejected |

pendingCount() soma a fila e as recusas abertas: é o número que o logout
mostra. As recusas esperam a decisão do usuário (capítulo 34).

## Preferências
"Mostrar concluídas" é do usuário, não do aparelho: fica na tabela
preferences do tasks.db e é apagada no logout com as tarefas, a fila, as
recusas e o sync_state. O AppPreferences do core guarda só o que é do aparelho (tema,
idioma) e sobrevive ao logout.

## Ligação no host
Passos 1 a 3 do checklist (capítulo 28): membro do workspace,
dependência do host e registerTasksModuleDependencies no init do escopo
da sessão. Passo 7 (capítulo 32): a fila no OutboxRegistry, enviada
também pelo outboxSyncDispatcher do host com o app fechado. Passo 4
(capítulo 34): tasksModuleRoutes no createAppRouter, dentro da moldura
do host, e a tela inicial redirecionando para TaskRoutes.listPath.
Passo 6 (capítulo 37): TasksModuleLocalizations.delegate na lista
moduleLocalizationsDelegates do app.dart.

## Fronteiras (capítulo 36)
O pubspec.yaml declara core, design_system, flutter, get_it, flutter_bloc,
bloc_concurrency e go_router, e, desde o capítulo 37, flutter_localizations
e intl, que só a classe de tradução gerada usa, no lado driving. Nenhum outro módulo, nenhum adaptador e
nenhuma tecnologia que o core abstrai. Cada capacidade que parece exigir
outro pacote chega por uma porta do core:

| Capacidade | Porta do core que o módulo usa | Quem implementa | Quem liga |
| --- | --- | --- | --- |
| Chamadas autenticadas e renovação do token | ApiClient | HttpApiClient, que lê o TokenProvider do auth_module a cada envio (capítulo 41) | host |
| Banco criptografado | LocalDatabaseFactory, LocalDatabase, DatabaseSchema | adapter_db_sqlcipher | host |
| Limpeza no logout | ClearableOnLogout, LogoutCleanerRegistry | auth_module chama clearAll() | função de registro do módulo |
| Pendências no logout e envio da fila | SyncableOutbox, OutboxRegistry | OutboxSyncWorker do core | função de registro do módulo |
| Envio com o app fechado e na volta da rede | nenhuma além do OutboxRegistry | adapter_sync_workmanager, SyncOrchestrator | host |
| Registro de falhas | AppLogger | adapter_logging_crashlytics | host |
| Erros | ApiError, LocalDatabaseError, Failure | core | — |

O módulo não usa TokenProvider, ConnectivityService, SyncScheduler,
AppPreferences nem AppAnalytics. Por camada: domain importa só o core
(Failure); application importa só o core, desde o capítulo 38, para o
AppAnalytics; adapters/driven importa
o core e dart:async, dart:convert e dart:math; adapters/driving importa o
core, o design_system, o Flutter, o flutter_bloc, o bloc_concurrency, o
go_router, só nas Pages o get_it e, só na classe de tradução gerada em
adapters/driving/l10n (capítulo 37), o flutter_localizations e o intl; o
arquivo de entrada importa o core e o get_it. As camadas apontam para dentro, e driving e driven não se
importam. O test/architecture/imports_test.dart confere tudo isso nos
arquivos; o check-deps confere o pubspec.yaml, e o
depend_on_referenced_packages barra o import de um pacote não declarado.

## Testes
Domínio e aplicação com mocktail; o repositório com o serviço remoto e o
local simulados; o RestTaskService com o ApiClient simulado; o lado
driven sobre o SQLite do computador (sqflite_common_ffi), com uma
LocalDatabaseFactory de teste que abre como o adaptador abre (esquema
completo ou migrações, transações de verdade, erro do driver como
LocalDatabaseError); o módulo inteiro pela função de registro, num
escopo de sessão, com o backend simulado no ApiClient. O
TaskSyncableOutbox sobre o SqliteTaskService de verdade e o ApiClient
simulado: um teste por destino de resposta. Capítulo 33: com a rede caída
(todo ApiClient lançando unreachable), criar, renomear, concluir, reabrir,
arquivar e mudar a preferência funcionam, a lista vem do banco, as
operações esperam na fila, e só o refreshTasks() (o gesto de atualizar)
devolve o erro. O módulo nunca lê o ConnectivityService. Capítulo 36:
test/architecture/imports_test.dart, os imports de cada camada lidos dos
arquivos. Capítulo 34: os
Blocs com o TaskUseCase simulado; as Views com Blocs simulados
(MockBloc) e um GoRouter com as rotas vizinhas; as Pages pelas rotas, com
os Blocs simulados no get_it; o SqliteTaskService em cada decisão; e um
conflito provocado de propósito no módulo inteiro: duas edições sem rede,
o 409 de versão, a tela de conflitos e "Manter a minha", que reenvia
tudo numa operação só sobre a versão do servidor.
Capítulo 39: cada View também com a fonte do sistema em 1,0, 2,0 e 3,0,
num telefone de 375 × 667 pontos (test/support/text_scale.dart): nada
transborda e as ações principais se alcançam. A lista é uma rolagem só
(aviso de conflitos, campo e tarefas num CustomScrollView), e o aviso tem
o botão "Resolver" abaixo do texto. No aparelho, o módulo é exercitado
pelos testes de integração do host (caminho feliz e fluxo offline).

## Eventos de produto (capítulo 38)
O TaskUseCase recebe o AppAnalytics e registra, depois de cada operação
que deu certo e sem esperar: tasks_task_created, tasks_task_renamed,
tasks_task_completed, tasks_task_reopened, tasks_task_archived e
tasks_conflict_resolved (parâmetros reason e choice, os nomes dos enums).
Nenhum evento leva o título nem o id da tarefa. As telas vistas são
registradas pelo host, pelo nome das rotas (tasks.list, tasks.edit,
tasks.conflicts).
