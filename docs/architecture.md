# mobile_tarefas — arquitetura

## Estrutura do workspace
Raiz neutra, host em mobile_tarefas_app/, bibliotecas em packages/,
ferramentas em tools/. Papéis pelo nome; check-deps no CI. Duas
ferramentas: tools/workspace_lints (o check-deps, capítulo 15) e
tools/dev_backend (capítulo 35), um servidor em memória que segue o
contrato dos módulos, para rodar o app no simulador sem backend de
verdade. Ferramentas nunca são dependência de outro pacote.

## Host
mobile_tarefas_app/ (capítulo 24), criado com o nome final, para Android e
iOS. É o único pacote que depende dos adaptadores. Desde o capítulo 28,
abre no login do auth_module quando não há sessão; com sessão, desde o
capítulo 34, na lista do tasks_module, dentro da moldura do host.

### Flavors (capítulo 26)
dev, staging e prod. Cada um tem três nomes que precisam concordar: o
--flavor do Android e do iOS, o lib/main_[flavor].dart e o
config/[flavor].json (--dart-define-from-file). O AppConfig confere os três
na abertura (appFlavor, o enum Flavor e a chave FLAVOR) e exige
API_BASE_URL https. A única exceção (capítulo 35): no flavor dev, http
na interface local (127.0.0.1, localhost, ::1), para o
config/dev_local.json, que aponta para o tools/dev_backend. Identificadores: com.zayitbrazil.mobiletarefas, com
.dev e .staging; nomes na tela: Tarefas Dev, Tarefas Stg e Tarefas.
Android: productFlavors com applicationIdSuffix e strings.xml por source
set. iOS: tool/configure_ios_flavors.rb (gem xcodeproj) cria as
configurações [Debug|Profile|Release]-[flavor], um xcconfig por
configuração em ios/Flutter/, um esquema compartilhado por flavor, o
CFBundleDisplayName = $(APP_DISPLAY_NAME) e o mapa do Podfile.

## Módulos (capítulo 42)
O índice dos módulos de feature: uma linha por módulo, com a página dele.
O check-deps confere que cada módulo do workspace tem a página em
docs/modules/, a linha nesta tabela e uma linha própria no
.github/CODEOWNERS, e que nenhuma página sobra de um módulo que saiu.

| Módulo | Assunto | Escopo do get_it | Dono | Página |
|---|---|---|---|---|
| auth_module | login, cadastro, sessão e logout | base | @olivgilberto | [modules/auth_module.md](modules/auth_module.md) |
| tasks_module | tarefas offline-first, sincronização e conflitos | sessão | @olivgilberto | [modules/tasks_module.md](modules/tasks_module.md) |

## Portas do core
Catálogo em packages/core/lib/core.dart (capítulo 17). O core não tem a seção
dependencies; o check-deps falha se ela aparecer.
## Adaptadores
Sete pacotes adapter_* (capítulo 18), um por tecnologia, cada um com a
família registrada em tools/workspace_lints/lib/src/dependency_rules.dart.
Lançam os erros do core (ApiError, LocalDatabaseError), nunca tipos próprios.
## Design system
packages/design_system (capítulo 19): tokens do Material 3 sobre uma cor
semente provisória, fonte Inter empacotada, AppTheme claro e escuro e os
componentes AppEmptyState, AppConnectivityBanner e AppErrorPlaceholder;
os de formulário (AppForm, AppTextField, AppPrimaryButton, AppTextButton e
AppInlineError) e o token AppBreakpoints.compactMaxWidth no capítulo 22;
o showAppConfirmDialog (confirmação de ação sem volta) no capítulo 29.
Depende só do Flutter; o check-deps recusa core, módulos e adaptadores.
## Injeção de dependências e escopo da sessão
Composition root em mobile_tarefas_app/lib/bootstrap/dependency_injection.dart
(capítulo 24). configureDependencies() liga cada porta do core ao seu
adaptador, sempre pelo tipo da porta, e registra os códigos sem tecnologia
do core (registries, ConnectivityService, OutboxSyncWorker,
SyncOrchestrator, SyncScheduler). O escopo da sessão acompanha os dados
do aparelho, e não o login (capítulo 32): o mainCommon o abre antes de
ler a sessão guardada, e o SessionGate o renova (renewSessionScope: fecha
e abre vazio) quando a sessão termina, sempre depois da limpeza; o dispose
do escopo esvazia os dois registries. O auth_module é registrado no escopo
base, depois das portas do core (capítulo 28): fornece o TokenProvider,
que o HttpApiClient resolve sob demanda, e o SessionBloc, um só do boot ao
fim do app; o host nunca observa o token. Uma sessão expirada com
alterações não enviadas (capítulo 29) leva ao login com o escopo aberto:
os dados e as filas esperam a decisão do usuário. O dono desses dados é
gravado no auth.db (capítulo 32), e por isso o mesmo estado volta depois
de um reinício. O tasks_module se registra no init do escopo da sessão
(capítulo 30) e inscreve o seu cleaner no LogoutCleanerRegistry e a sua
fila no OutboxRegistry (capítulo 32).
### Segundo plano (capítulo 32)
mobile_tarefas_app/lib/bootstrap/background_sync.dart: outboxSyncDispatcher,
ligado ao workmanager pelo adapter_sync_workmanager (o host não importa o
workmanager). O boot agenda a tarefa periódica outbox_sync (1 h, só com
rede, ExistingPeriodicWorkPolicy.keep) no fim do passo 4; uma falha vai ao
registro de falhas e não impede o app de abrir. Cada execução, num isolate
com o get_it vazio: Firebase, configureDependencies(AppConfig.forBackground())
e allReady uma vez por isolate; sem sessão guardada, termina sem enviar;
com sessão, abre o escopo da sessão e roda o OutboxSyncWorker, devolvendo
ao sistema o contrário de "algo ficou para depois". iOS: Info.plist com
BGTaskSchedulerPermittedIdentifiers (outbox_sync) e UIBackgroundModes
(fetch); o AppDelegate registra os plugins no engine de segundo plano e a
tarefa periódica com o mesmo identificador. Android: nada além do
workmanager.
### Conectividade (capítulo 33)
Três camadas, só como dica: NetworkInterfaceMonitor (connectivity_plus),
ReachabilityProbe (HEAD em /v1/health, num cliente http próprio, sem
token nem nova tentativa, 3 s; qualquer resposta HTTP conta como alcançável) e o
DefaultConnectivityService do core (unknown, offline, noInternet, online;
nova verificação com espera crescente de 15 s a 5 min enquanto
noInternet). O mainCommon chama startConnectivity() depois de abrir o
escopo da sessão e de ler a sessão guardada: o SyncOrchestrator.start()
(sincroniza a cada transição para online, intervalo de 2 s, uma execução
por vez, e na hora se já estiver online) e o ConnectivityService.start(),
nunca aguardado. O ConnectivityBannerHost (lib/connectivity/) fica no
builder do MaterialApp.router, abaixo de todas as telas: AppConnectivityBanner
do design_system visível em offline e noInternet, com os textos do host
(MobileTarefasLocalizations, capítulo 37); a tela continua inteira e tocável. Nenhuma
ação de módulo consulta o estado de conexão: o teste do tasks_module faz
todas as escritas com a rede caída, e só o gesto de atualizar mostra o
erro.
Desde o capítulo 35, o ApiClient registrado é o
ConnectivityReportingApiClient do core em volta do HttpApiClient: uma
requisição que não chega com o estado online pede uma verificação, e
qualquer resposta com o estado noInternet também. Sem isso, um backend que
cai ou volta com a interface ligada passava despercebido (achado do
roteiro no simulador): sem aviso, e a fila só subia na escrita seguinte.
Com o estado unknown (segundo plano) nada é pedido.
## Roteamento e sequência de boot
Boot em mobile_tarefas_app/lib/bootstrap/boot.dart (capítulo 25): Firebase
(falha tolerada, com tempo limite), handlers globais de erro, injeção de
dependências com allReady sob tempo limite e leitura das preferências
(AppSettings, com padrões se a leitura falhar). Cada passo espera no máximo
bootStepTimeout (5 s). O mainCommon (main_common.dart) lê o AppConfig,
chama boot(), pede ao SessionBloc a sessão guardada e espera a leitura com
o mesmo tempo limite (o fim do passo 5), e chama runApp. O roteador
(app_router.dart) é um GoRouter com refreshListenable nas AppSettings e no
SessionGate e um redirect puro, appRedirect, com duas regras em ordem. 1:
sem idioma escolhido, tudo vai para /language. 2: sem sessão, tudo o que
não é /auth/ vai para o login; com sessão, as telas de /auth/ levam ao
destino. As duas preservam o destino em ?from= (só caminhos internos).
Rotas do host: app.home (/) e app.language (/language); as do auth_module
entram espalhadas (authModuleRoutes). Desde o capítulo 34, app.home
redireciona para a lista de tarefas (/tasks), e as rotas do tasks_module
entram num ShellRoute com a AppFrame do host (lib/home/app_frame.dart): a
tela do módulo e, abaixo dela, o LogoutButton do auth_module. A
HomePlaceholderPage saiu.

### Ligação de um módulo (capítulo 28)
Um módulo novo muda fora do próprio pacote só estes lugares: 1. a lista
workspace: da raiz; 2. o pubspec.yaml do host; 3. uma linha em
configureDependencies() (escopo base) ou no init de openSessionScope()
(escopo da sessão, módulos de feature); 4. um espalhamento em
createAppRouter; 5. uma regra no redirect, só se o módulo decide quem
entra (o auth_module); 6. o delegate de tradução do módulo na lista
moduleLocalizationsDelegates do app.dart, quando o módulo tiver telas
(capítulo 37); 7. a sincronização em segundo plano,
quando tiver fila de envio (capítulo 32); 8. docs/modules/[módulo].md, a
linha no índice Módulos desta página e a linha no .github/CODEOWNERS,
conferidas pelo check-deps (capítulo 42); 9. o verificar.sh.
## Rede
adapter_http_http (capítulo 41, no lugar do adapter_http_dio dos capítulos
18 e 27): HttpApiClient, com o pacote http. Autenticação, no próprio envio:
põe o token quando há TokenProvider e, diante de um 401 numa requisição que
levou o token, pede uma renovação (uma vez) e repete com uma requisição
nova; post(..., authenticated: false) passa sem token e sem renovação, e
é o que a própria renovação usa. Uma renovação sem rede sobe como o
ApiError dela (transitório), não como o 401. Log: método, caminho, status e
duração, nunca cabeçalhos, query ou corpos. Log e tempo limite (20 s), por
tentativa, num cliente interno. Nova tentativa: o RetryClient do pacote,
só falhas transitórias (5xx e transporte), três tentativas, espera
exponencial com jitter; o Idempotency-Key vai em todas. O Dio continua
proibido nos módulos, pela lista de tecnologias aposentadas do check-deps. Só HTTPS: AppConfig exige https,
network_security_config.xml no Android (sem texto claro, só CAs do
sistema) e o ATS padrão no iOS, sem exceções no Info.plist.
## Persistência e sincronização
Um banco SQLCipher por módulo (auth.db, tasks.db), aberto pela porta
LocalDatabaseFactory (capítulos 18 e 30): chave aleatória de 256 bits por
banco no armazenamento seguro (Keychain com first_unlock_this_device no
iOS), arquivos em Application Support/local_databases. Fora do backup:
no iOS, o AppDelegate marca a pasta com isExcludedFromBackup a cada
abertura; no Android, allowBackup="false" e data_extraction_rules.xml
excluem files/local_databases/ e shared_prefs (onde fica o armazenamento
seguro) do backup na nuvem e da transferência entre aparelhos. Cada
módulo declara o seu DatabaseSchema com o esquema completo da versão
atual e as migrações; versão publicada nunca muda (teste de esquema por
módulo). Leitura stale-while-revalidate com TTL por tipo de dado e
paginação por cursor; escritas gravam a operação na fila do módulo na
mesma transação (capítulo 31). O envio da fila (capítulo 32) segue a
ordem de gravação com um envio por vez em cada isolate; criação por PUT
com o id do app, alteração e arquivamento por PATCH com a versão base, o
id da operação no corpo e no Idempotency-Key. Destinos: 2xx sai da fila e
reapoia as operações seguintes da tarefa na versão nova; transitório,
resposta ilegível, 401, 429 e 409 que não é de versão ficam e param a
rodada; 404 num arquivamento sai; 409 de versão e outros 4xx vão para
sync_conflicts, e as operações seguintes da tarefa esperam a decisão. Preferências do aparelho (tema, idioma) no AppPreferences;
preferências do usuário no banco do módulo, apagadas no logout.
Verificação manual antes de cada versão publicada (nenhum teste
automatizado a cobre): um backup do aparelho, restaurado em outro, chega
sem a pasta local_databases e sem o armazenamento seguro, e o app abre
vazio e baixa os dados na primeira sincronização. Também antes de cada
versão que traz uma migração: instalar a versão anterior num simulador,
criar dados, instalar a nova por cima e abrir. Os testes de esquema rodam
sobre o SQLite do computador, e não sobre o SQLCipher do aparelho (a
migração 2 do tasks.db usa json_object, embutido no SQLite desde a
3.38.0). Desde o capítulo 32, também: a sincronização em segundo plano
num aparelho de verdade (Android: app fechado, uma alteração feita sem
rede, rede de volta, a fila esvazia em até um ciclo; iOS: a tarefa
outbox_sync disparada pelo depurador do Xcode), e duas pessoas no mesmo
aparelho (Ana sai por expiração com alterações pendentes, o app é
fechado, Bia entra e não vê nada de Ana).
## Internacionalização
Capítulo 37. Cada pacote com telas tem os próprios ARB e a própria classe
gerada pelo gen-l10n (l10n.yaml no pacote; o ARB em inglês é o modelo, com
descrição em toda chave e =0 em todo plural): auth_module, tasks_module e o
host. O host junta os delegates em moduleLocalizationsDelegates, no
app.dart, e um teste confere que cada um traduz todos os idiomas de
AppLanguages (pt e en). O idioma é escolhido no primeiro uso, guardado pela
porta AppPreferences e trocado na tela app.language. O design_system não
tem ARB: os componentes recebem os textos prontos.

## Observabilidade
Capítulos 14 e 38. AppLogger → CrashlyticsAppLogger
(adapter_logging_crashlytics); AppAnalytics → FirebaseAppAnalytics
(adapter_analytics_firebase). Um projeto do Firebase por flavor
(mobile-tarefas-dev, -staging, -prod), com as opções escolhidas por
firebaseOptionsFor(flavor). Handlers globais (lib/bootstrap/error_handling.dart)
levam ao AppLogger os erros do Flutter e da plataforma; o AppBlocObserver,
os que escapam dos Blocs. As telas vistas são registradas pelo host, pelo
nome das rotas (ScreenViewObserver, um por navegador). Os eventos de
produto são dos casos de uso, depois da operação que deu certo, no formato
[módulo]_[objeto]_[verbo]; nenhum dado pessoal, segredo ou valor único
(o usuário é um id opaco). Símbolos dos builds ofuscados enviados pelo CI.

## Segurança
Capítulos 14, 30 e 38. Banco local criptografado (SQLCipher), com a chave
no armazenamento seguro da plataforma; um arquivo por módulo, apagado no
logout pelo LogoutCleanerRegistry. Android: allowBackup="false" e
data_extraction_rules, para que nada vá ao backup; network_security_config
sem tráfego em texto claro e só com as autoridades certificadoras do
sistema (capítulo 27). API só em https, salvo a interface local no flavor
dev (AppConfig, capítulo 35). Builds de
produção ofuscados; nenhum segredo no app nem no --dart-define-from-file.
iOS: App Tracking Transparency depois do primeiro quadro, com o app ativo,
e nenhuma função depende da resposta. Root e jailbreak verificados com o
safe_device só em aparelho real, com aviso num MaterialBanner, sem
bloquear o app. Sem certificate pinning: o app não trata dados
financeiros nem de saúde.
## CI/CD
Repositório privado no GitHub (capítulo 40). `.github/workflows/ci.yml`: em todo pull request e push na `main`, formatação, `melos analyze` (com o plugin `workspace_lints`), `check-deps` e testes, cada um com `if: !cancelled()`; nos pull requests, APK de depuração dos três flavors; na `main`, app bundles de staging e prod assinados com a chave de upload (segredos `ANDROID_*`), certificado conferido com `keytool`, `--obfuscate --split-debug-info`, `--build-number` = `github.run_number`, símbolos do Dart enviados com `firebase crashlytics:symbols:upload` e o mapeamento do R8 enviado pelo plugin do Crashlytics no Gradle (contas de serviço `FIREBASE_SA_STAGING`/`FIREBASE_SA_PROD`, só com o papel do Crashlytics), e o iOS de prod com `--no-codesign`. `.github/workflows/integration.yml`: os testes de integração no emulador do Android (api 35), só à mão (desde 05/11/2026, por causa do online_journey que não carrega no emulador do CI). `renovate.json`: patch com automerge, major com aprovação no painel.
Em aberto: avisos de KGP e de `--strip`, proteção da `main` (plano da conta), app do Renovate, assinatura do iOS.

## Decisões registradas
| Data | Decisão | Motivo |
|---|---|---|
| 2026-10-18 | Host para Android e iOS, com org com.zayitbrazil | Plataformas do produto; os identificadores finais por flavor vêm no capítulo 26 |
| 2026-10-18 | SyncScheduler registrado só no capítulo 32 | O adaptador exige o dispatcher de segundo plano, que nasce com a outbox (registrado no capítulo 32) |
| 2026-10-26 | Tela de escolha de idioma no host desde o capítulo 25 | É a primeira regra do redirect; sem ela o boot não teria destino real. O ARB e as traduções continuam no capítulo 37 |
| 2026-10-26 | Configuração de plataforma dos deep links adiada | App Links e Universal Links exigem um domínio próprio; o redirect já aceita destinos internos via ?from= |
| 2026-10-26 | Identificadores com.zayitbrazil.mobiletarefas (+ .dev e .staging) e nomes Tarefas Dev, Tarefas Stg e Tarefas | O identificador da loja não deriva do nome do pacote Dart; os três flavors instalam lado a lado |
| 2026-10-26 | Nome do app no Android por strings.xml em cada source set, sem resValue | O resValue falha por padrão a partir do AGP 9 |
| 2026-10-26 | Ícone por flavor adiado até o produto ter um ícone | Sem marca, um ícone por ambiente seria um placeholder para trocar depois |
| 2026-10-26 | Arquivos config/[flavor].json versionados, sem segredos | Só endereços e nomes; segredos entram pelo CI (capítulo 40) |
| 2026-10-26 | ApiClient.post ganhou authenticated (padrão true) | A requisição de renovação não pode levar o token vencido nem disparar outra renovação; só post porque os pedidos sem sessão do produto são todos post |
| 2026-10-27 | auth_module no escopo base; o host observa o SessionBloc, nunca o token | Ele mostra o login, então existe antes da sessão; o estado só vira "encerrada" depois da limpeza (capítulo 11) |
| 2026-10-27 | Logout como LogoutButton exportado pelo auth_module, na moldura das telas do host | Sair é uma ação, não uma tela; uma rota em /auth/ seria desviada pelo redirect de quem tem sessão |
| 2026-10-27 | Dono dos dados locais só em memória até o capítulo 32 | Sem fila de envio, não há sessão expirada com pendências no app; a fila traz o caso e a persistência (resolvido no capítulo 32) |
| 2026-10-27 | Sessão guardada lida no fim do passo 5 do boot, com tempo limite | Sem ela, quem tem sessão veria o login por um instante; passado o tempo, o app abre no login e segue sozinho quando a leitura terminar |
| 2026-10-27 | Preferências do usuário no banco do módulo; AppPreferences só para as do aparelho | As do usuário somem no logout com os dados dele; tema e idioma são do aparelho e sobrevivem a ele |
| 2026-10-27 | allowBackup="false" e data_extraction_rules no Android; pasta local_databases fora do backup no iOS | As chaves dos bancos nunca saem do aparelho; um banco restaurado sem a chave seria ilegível |
| 2026-10-27 | Id das tarefas gerado no aparelho (UUID v4, sem dependência) | A tarefa existe antes de chegar ao backend, e reenviar a criação não a duplica (capítulo 32) |
| 2026-10-27 | Escritas gravam a operação na fila desde o capítulo 31; o envio vem no 32 | A atualização pela rede precisa saber o que o usuário fez e o servidor ainda não sabe; sem a fila, ela apagaria as tarefas criadas no aparelho |
| 2026-10-27 | Entre os capítulos 31 e 32, a fila de tarefas existe mas não está no OutboxRegistry: o logout não a conta | Inscrever só a contagem exigiria um sync() que não envia nada; nenhum usuário alcança o caminho sem a tela, e o capítulo 32 inscreve a fila de verdade (fechado no capítulo 32) |
| 2026-10-28 | Dono dos dados gravado no auth.db (versão 2), e não na fila do tasks_module como previsto | Depois de um reinício sem sessão, o escopo da sessão não estava aberto: o auth_module não leria o dono na fila de outro módulo, nem acharia quem apagar. Só o id, apagado depois dos dados; um dono ilegível recusa o login |
| 2026-10-28 | Escopo da sessão aberto no boot e renovado a cada fim de sessão | Dados de uma sessão expirada podem estar no aparelho antes de se saber quem entra; só os módulos registrados sabem contá-los e apagá-los. As telas continuam protegidas pelo redirect |
| 2026-10-28 | tasks.db versão 3: só sync_conflicts | O dono foi para o auth.db; a tabela de recusas nasce com o envio |
| 2026-10-28 | Sucesso do envio lê a versão nova e reapoia as operações seguintes da tarefa | Sem isso, criar e logo renomear sem rede geraria um 409 contra a própria alteração do usuário |
| 2026-10-28 | 409 só é conflito com {"code": "version_conflict"}; outro 409 fica na fila | O rascunho do Idempotency-Key responde 409 à mesma chave ainda em processamento, o caso do app aberto e do segundo plano enviando juntos |
| 2026-10-28 | SyncOrchestrator.start() no capítulo 33, não no 32 | Ele depende do ConnectivityService.start(), que entra com a conectividade; até lá, a fila sobe depois de cada escrita e em segundo plano |
| 2026-10-28 | Conectividade ligada no mainCommon, depois do escopo da sessão, e não no boot() | A primeira sincronização precisa das filas dos módulos, inscritas no escopo da sessão; o boot() continua sem saber de sessão |
| 2026-10-28 | Aviso de conexão abaixo das telas, no builder do MaterialApp.router, nunca modal | É dica, não regra: a tela continua tocável, e nenhuma ação depende do estado |
| 2026-10-28 | O orquestrador sincroniza mesmo sem sessão | As filas sem token recebem 401 e ficam; só a sessão expirada com pendências tem fila nesse estado, e o envio volta a funcionar no login |
| 2026-10-28 | Tela inicial de quem entrou é a lista de tarefas, por redirect de / para /tasks | O host continua dono de /, e o módulo, dos próprios caminhos; um segundo módulo de feature muda só o destino |
| 2026-10-28 | Moldura das telas (botão de sair) num ShellRoute do host | O tasks_module não conhece o auth_module; quem junta os dois é o host |
| 2026-10-28 | A versão do servidor é consultada de novo no momento da decisão sobre um conflito | Entre abrir a tela e decidir, a tarefa pode ter mudado outra vez; a base velha geraria outro 409 |
| 2026-10-28 | "Refazer" grava a versão do servidor e abre a tela da tarefa | A alteração recusada nunca passaria como está; o usuário age de novo sobre o estado atual |
| 2026-10-28 | Backend de desenvolvimento em memória em tools/dev_backend (shelf), escolhido com o usuário para o roteiro do capítulo 35 | O projeto não tem backend; um servidor que segue o contrato, com rotas de "outra pessoa", deixa provocar conflitos, recusas e renovação no simulador. O teste de contrato o lê com o DioApiClient e os Services dos módulos |
| 2026-10-28 | http aceito só no flavor dev e só na interface local | O simulador do iOS compartilha o 127.0.0.1 do computador, e o emulador do Android o alcança por adb reverse; nada sai da máquina sem TLS, e staging e prod continuam só com https |
| 2026-10-28 | As requisições alimentam o ConnectivityService por um decorador do core no ApiClient | O serviço só verificava ao começar e quando a interface mudava; no roteiro do capítulo 35, o backend fora do ar não mostrou aviso e a fila não subiu sozinha quando ele voltou. O decorador fica no core, sem tecnologia, e nenhum módulo passa a ler o estado de conexão |
| 2026-10-28 | As tecnologias que um módulo não pode declarar vêm das famílias dos adaptadores, e não de uma segunda lista | A lista escrita à mão deixava passar flutter_secure_storage e path_provider, da família do banco; um adaptador novo passa a proteger as suas tecnologias ao entrar na tabela |
| 2026-10-28 | Teste de imports por camada dentro do tasks_module até o plugin do analisador (capítulo 40) | O check-deps vê o pubspec.yaml do pacote inteiro; as camadas são pastas do mesmo pacote, e só uma leitura dos arquivos as distingue |
| 2026-10-27 | TTL de 5 minutos para a lista de tarefas, com atualização forçada pelo gesto de puxar | O usuário já vê as próprias mudanças; o TTL só cobre as feitas em outro aparelho |
| 2026-10-26 | Sem certificate pinning | Quedas na rotação de certificados; o network_security_config fica só com as CAs do sistema (capítulo 14) |
| 2026-10-29 | Traduções por pacote com o gen-l10n: l10n.yaml e ARB em cada módulo com telas e no host; ARB e classe gerada no lado driving do módulo (lib/adapters/driving/l10n) | Texto é coisa de tela; o domínio não tem nenhum, e o teste de imports aceita o flutter_localizations e o intl só no driving |
| 2026-10-29 | ARB "pt" (português do Brasil) e "en" (template); o host oferece pt-BR e en | O delegate gerado decide pelo código do idioma, e pt-BR cai no "pt"; um pt_PT, se vier, ganha o próprio ARB |
| 2026-10-29 | nullable-getter: false e required-resource-attributes: true em todo l10n.yaml | Sem `!` em cada tela, e toda chave com a descrição para quem traduz |
| 2026-10-29 | Um teste por pacote confere que toda tradução tem as chaves do template, e um teste do host que todo delegate traduz todos os idiomas do app | Para o gen-l10n, uma chave sem tradução é aviso, e a tela mostraria o template, em inglês |
| 2026-10-29 | Firebase real só no flavor dev (projeto mobile-tarefas-dev); staging e prod no capítulo 40 | Decisão do usuário. firebaseOptionsFor(flavor) entrega as opções geradas pelo flutterfire configure; sem opções, o boot segue sem o Firebase. No Android, missingGoogleServicesStrategy = WARN para os flavors sem google-services.json |
| 2026-10-29 | App Tracking Transparency depois do runApp, quando o app fica ativo, e não no passo 2 do boot | A Apple ignora, sem erro, o pedido feito com o app ainda inativo |
| 2026-10-29 | Root e jailbreak com o safe_device, só em aparelho real, aviso num MaterialBanner do host | Decisão do usuário pelo pacote; emuladores e simuladores costumam parecer aparelhos com root; o mobile_tarefas não tem funcionalidade sensível para desligar |
| 2026-10-29 | Telas vistas registradas por um ScreenViewObserver no GoRouter e outro no ShellRoute; erros de Bloc pelo AppBlocObserver | Um NavigatorObserver serve a um navegador só, e a moldura tem o seu |
| 2026-10-29 | Build de produção ofuscado, com os símbolos em build/symbols/prod | O envio dos símbolos ao Crashlytics é do CI (capítulo 40) |
| 2026-11-02 | Toda View é testada com a fonte do sistema em 1,0, 2,0 e 3,0 num telefone de 375 × 667 pontos: nada transborda e as ações principais se alcançam | Android 14 vai a 200%, o maior tamanho do iOS passa de 3×; os testes acharam o diálogo de confirmação sem rolagem e o aviso de conflitos espremido |
| 2026-11-02 | Testes de integração em mobile_tarefas_app/integration_test, num script à parte (verificar_integracao.sh), no simulador do iOS e no emulador do Android | Decisão do usuário; pedem aparelhos e minutos, e o verificar.sh segue rápido. Cada arquivo roda num app instalado do zero, contra o dev_backend |
| 2026-11-02 | O teste de integração usa o mainCommon de verdade, sem Firebase, sem handlers globais e sem o pedido de rastreamento | Eventos de teste não vão ao console de uso; o framework de testes é quem trata os erros; o alerta do sistema está fora do alcance do teste |
| 2026-11-02 | dev_backend com porta de controle (--control-port): /control/stop e /control/start fecham e abrem a porta da API | Decisão do usuário; o teste offline, no aparelho, precisa de conexão recusada de verdade, como um servidor fora do ar |
| 2026-11-02 | Nenhuma exceção de texto claro no Android para o dev_backend | O Dio usa sockets do Dart, a que a política de rede do Android não se aplica; testado no emulador sem o arquivo. Volta, com um teste, se o app ganhar uma pilha de rede nativa |
| 2026-11-03 | Repositório privado no GitHub, com GitHub Actions | Decisão do usuário; os segredos de assinatura e das contas de serviço ficam nos segredos do repositório |
| 2026-11-03 | As verificações do CI rodam todas, mesmo depois de uma falha (`if: !cancelled()`) | O pull request mostra todos os problemas de uma vez; o `always()` rodaria até depois de um cancelamento |
| 2026-11-03 | Builds de release só na `main`: Android de staging e prod assinados e ofuscados; iOS sem assinatura | Decisão do usuário; os pull requests compilam os três flavors em depuração, sem segredo; o iOS assinado pede o Apple Developer Program |
| 2026-11-03 | Testes de integração no CI só no Android, a cada merge na `main` e à mão | Decisão do usuário; um emulador e quase vinte minutos por execução não cabem em cada pull request; o iOS continua no verificar_integracao.sh |
| 2026-11-03 | Um projeto do Firebase por flavor (dev, staging e prod); a estratégia WARN do google-services saiu | Decisão do usuário; os números de produção não se misturam aos dos testes |
| 2026-11-03 | O `analysis_options.yaml` de cada pacote inclui o da raiz, que declara o plugin `workspace_lints` | O analisador usa o arquivo de opções mais próximo; sem a inclusão, o plugin carrega e não roda nos pacotes (dart-lang/sdk#62161) |
| 2026-11-03 | Os testes do `workspace_lints` rodam com `dart test` | O `test_reflective_loader` usa `dart:mirrors`, que o `flutter test` não compila |
| 2026-11-03 | Chave de upload fora do repositório; release sem `key.properties` sai com a chave de depuração, e o CI falha se o segredo faltar ou se o certificado for o de depuração | Builds locais de release continuam possíveis sem a chave; a loja nunca recebe um build assinado errado |
| 2026-11-03 | O Dio sai e entra o pacote http, num adapter_http_http; o adapter_http_dio é removido do workspace | Decisão do usuário (capítulo 41): prova da troca de tecnologia sem serviço externo; nenhum módulo muda |
| 2026-11-03 | Os 17 testes do adaptador do Dio são portados um a um, com os mesmos nomes e expectativas; só o servidor simulado muda (MockClient) | Decisão do usuário: os testes antigos são o contrato do adaptador novo |
| 2026-11-03 | Nova tentativa pelo RetryClient do pacote http, com as regras do Dio (3 tentativas, 5xx e transporte, exponencial com jitter) | Decisão do usuário; o padrão do RetryClient só repete 503 |
| 2026-11-03 | Tecnologia de adaptador removido entra em retiredTechnologies do check-deps | Sem ela, a família sai com o adaptador e o Dio voltaria a ser aceito num módulo |
| 2026-11-05 | Na integração do CI, o Gradle usa até 3 GB, sem daemon, e o Kotlin compila dentro dele | A máquina de um repositório privado tem 8 GB, e o gradle.properties do template reserva até 8 GB; com o emulador ligado, a máquina caía (capítulo 41) |
| 2026-11-05 | check-deps confere, para cada módulo de feature, a página em docs/modules/, a linha no índice desta página e uma linha própria no .github/CODEOWNERS | Com vinte módulos, a documentação e o dono deixam de ser lembrados de cabeça; uma página sem módulo também é recusada |
| 2026-11-05 | Módulo novo pelo checklist do capítulo 28, sem brick do Mason nem cópia de um módulo existente | O modelo copiado envelhece com o projeto, e seis dos nove passos ficam fora do pacote; o check-deps aponta o que faltou, venha o módulo de onde vier |
| 2026-11-05 | Listas de pacotes com traduções e de módulos com cobertura derivadas da lista workspace: da raiz, no verificar.sh e no CI | Uma lista escrita à mão é um passo a mais, e esquecível, a cada módulo |
| 2026-11-05 | integration.yml só à mão (workflow_dispatch), sem o push na main | O terceiro arquivo não carrega no emulador do CI ("Failed to start Dart Development Service") em quatro execuções seguidas e passa no Mac; um X permanente ensina a ignorar o CI. A integração segue no verificar_integracao.sh antes de cada versão |
| 2026-11-05 | Plugin do Crashlytics no Gradle (com.google.firebase.crashlytics 3.0.8): o build de release do Android envia o mapeamento do R8 | Decisão do usuário: os símbolos do Dart já chegavam pelo CI, mas uma falha no código Kotlin/Java de um plugin chegaria ofuscada. Com o plugin, os dois lados da pilha chegam legíveis |
