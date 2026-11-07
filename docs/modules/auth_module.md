# auth_module

## Escopo
Login com e-mail e senha, cadastro, sessão restaurada no boot, logout com
limpeza dos dados de todos os módulos e sessão expirada.

## Arquitetura
- domain/: User (igualdade pelo id), EmailAddress e Password (value
  objects com parse), a família selada AuthFailure.
- application/: a porta AuthRepository e o AuthUseCase, que valida o texto
  da tela, identifica o usuário no AppLogger (id opaco) e registra os
  eventos auth_session_started, auth_account_registered,
  auth_session_ended e auth_session_expired.
- adapters/driven/: capítulo 21. adapters/driving/: capítulo 22.

## Política de senha
NIST SP 800-63B-4, senha como único fator: 15 a 128 caracteres, contados
como pontos de código, sem regras de composição. A lista de senhas
comprometidas é verificada pelo backend, que responde com o código de
senha fraca (WeakPasswordFailure).

## Testes
Domínio e aplicação em Dart puro, com mocktail para as portas
(capítulo 20). Lado driven com o ApiClient simulado e o banco da sessão
no computador (capítulo 21). Lado driving (capítulo 22): Blocs com
bloc_test e o AuthUseCase simulado, Views com um MockBloc em estado fixo,
rotas com um GoRouter de teste. Capítulo 39: cada View também com a
fonte do sistema em 1,0, 2,0 e 3,0, num telefone de 375 × 667 pontos
(test/support/text_scale.dart); a confirmação de saída rola, pelo
showAppConfirmDialog do design_system. No aparelho, o cadastro, o login e
o logout passam pelos testes de integração do host.

## Adaptadores driven (capítulo 21)
- RestAuthService implementa AuthRepository sobre o ApiClient.
- AuthTokenProvider implementa TokenProvider (core) e AuthSessionStore
  (interno): sessão lida uma vez, renovação compartilhada, recusa
  (ApiError rejected) encerra a sessão, falta de rede a preserva.
- A sessão (usuário e dois tokens) fica na tabela session do banco
  auth.db, aberto pela LocalDatabaseFactory (SQLCipher, chave no
  Keychain, fora do backup).
- Desde o capítulo 32, o auth.db tem a versão 2 (auth_database_schema.dart,
  com teste de esquema): a tabela data_owner, uma linha com o id do dono
  dos dados guardados no aparelho, lida e gravada pelo
  SqliteDataOwnerService (porta DataOwnerRepository).

## Contratos de erro com o backend
| Status | Código | Falha |
| --- | --- | --- |
| 401 | invalid_credentials | InvalidCredentialsFailure |
| 422 | email_already_registered | EmailAlreadyRegisteredFailure |
| 422 | weak_password | WeakPasswordFailure |
Qualquer outro erro continua ApiError.

## Adaptadores driving (capítulo 22)
- LoginPage/LoginView/LoginBloc e RegisterPage/RegisterView/RegisterBloc.
  Os Blocs dependem só do AuthUseCase, usam droppable() no envio e tratam
  AuthFailure (mensagem por falha, escolhida pela View) e ApiError ou
  LocalDatabaseError (mensagem genérica; tentar de novo é tocar no botão
  outra vez).
- Depois do sucesso a tela não navega: o redirect do host, que observa o
  estado da sessão, leva o usuário adiante.
- Componentes visuais só do design_system (AppForm, AppTextField,
  AppPrimaryButton, AppTextButton, AppInlineError). Textos nos ARB do
  módulo (capítulo 37): lib/adapters/driving/l10n/auth_module_en.arb
  (template) e auth_module_pt.arb, gerando a AuthModuleLocalizations,
  exportada pelo arquivo de entrada. Plurais no ARB (sessão expirada com
  alterações, logout com alterações).

## Navegação (contrato público)
| Nome | Caminho | Tela |
| --- | --- | --- |
| auth.login | /auth/login | LoginPage |
| auth.register | /auth/register | RegisterPage |
O host usa AuthRoutes.prefix e AuthRoutes.loginPath no redirect. Renomear
uma rota quebra o host: os nomes e caminhos só mudam junto com ele.

## Estado da sessão (contrato público, capítulo 28)
O SessionBloc, exportado com os estados SessionUnknown,
SessionAuthenticated e SessionUnauthenticated e o evento
SessionRestoreRequested, é o que o host observa no lugar do token. Um só,
registrado no escopo base. Escuta o AuthUseCase.watchSignedIn(), que
publica true no login, no cadastro e na sessão restaurada, e false quando
a sessão termina, sempre depois do clearAll(). Uma expiração (renovação
recusada) sem alterações pendentes é encerrada pelo próprio Bloc com
endExpiredSession(); com alguma (ou sem conseguir contar), o Bloc emite
SessionExpiredWithPendingChanges(pendingChanges) e espera: a tela de
login avisa e oferece entrar de novo ou descartar
(SessionDiscardRequested, com confirmação). Um banco da sessão ilegível
na restauração vira SessionUnauthenticated.

## Logout (capítulo 29)
O LogoutButton, exportado, é o ponto de entrada do logout: o host o põe
na moldura das telas. LogoutBloc (fábrica): LogoutRequested →
LogoutCheckInProgress → LogoutCheckSuccess(pendingChanges) ou
LogoutCheckFailure; a View pede confirmação quando há pendências (ou
quando não deu para contar) e só então envia LogoutConfirmed →
LogoutSubmitInProgress → LogoutSubmitSuccess (também sem rede: os dados
locais já foram apagados) ou LogoutSubmitFailure (limpeza falhou). A
confirmação usa o showAppConfirmDialog do design_system.

## Outra pessoa depois de uma sessão expirada
O dono dos dados é gravado no auth.db (capítulo 32): só o id opaco, nunca
nome ou e-mail. O login e o cadastro leem o dono antes de ir ao backend
(um dono ilegível recusa o login antes de guardar qualquer token); se
quem entrou é outra pessoa, os dados da anterior são apagados (clearAll)
e só então o dono muda, antes de a nova sessão ser publicada. A mesma
pessoa encontra tudo como deixou. O logout e o descarte apagam o dono
depois dos dados; uma limpeza que falha deixa o dono gravado, e a próxima
entrada de outra pessoa apaga de novo. A sessão restaurada no boot faz a
mesma comparação. Sem sessão guardada, mas com dono, a sessão expirou
antes de o app fechar: restoreSession() não publica nada e avisa a
expiração pelo watchSessionExpired(), e o SessionBloc segue o caminho de
sempre (conta as pendências; com alguma, SessionExpiredWithPendingChanges;
sem nenhuma, encerra). O host abre o escopo da sessão antes dessa
leitura, para que as filas e os cleaners dos módulos estejam inscritos.
Uma falha na limpeza vai ao AppLogger e sobe.

## Ligação ao host (capítulo 28)
O host depende do pacote, chama registerAuthModuleDependencies(getIt) no
escopo base, espalha authModuleRoutes no GoRouter, usa AuthRoutes no
redirect, observa o SessionBloc e põe o LogoutButton na moldura das telas
(capítulo 29). Passo 6 (capítulo 37): AuthModuleLocalizations.delegate
na lista moduleLocalizationsDelegates do app.dart. Sem fila de envio. Desde o capítulo 32, o host abre o escopo da sessão antes de pedir
a sessão guardada e o renova a cada fim de sessão.
