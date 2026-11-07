# dev_backend

Um backend em memória que fala o contrato do mobile_tarefas, para rodar o
app no simulador sem servidor de verdade (capítulo 35). Ferramenta de
desenvolvimento: nunca dependência de outro pacote, nunca em produção.

```sh
# da raiz do workspace
dart run tools/dev_backend/bin/dev_backend.dart [--port 8080] [--token-minutes 15] [--control-port 8081]
```

- Escuta só em `127.0.0.1`. Contas, sessões e tarefas ficam em memória:
  parar o processo apaga tudo, e o app volta ao login na próxima
  renovação.
- Cada requisição aparece numa linha (método, caminho e status), sem
  corpo e sem token.
- No terminal do servidor, `parar` fecha a porta sem perder o estado
  (o app vê conexões recusadas, como um backend fora do ar) e `voltar`
  abre de novo.
- Com `--control-port 8081`, as mesmas duas ações chegam por HTTP, numa
  porta à parte, que continua aberta quando a da API fecha (capítulo 39):
  `POST /control/stop`, `POST /control/start` e `GET /control/status`,
  que respondem `{"open": true|false}`. É por ela que os testes de
  integração, rodando no aparelho, tiram o backend do ar.

## O contrato

| Rota | O que faz |
| --- | --- |
| `GET`/`HEAD /v1/health` | 200, sem autenticação |
| `POST /v1/auth/register` | 201 com usuário e tokens; 422 `email_already_registered` ou `weak_password` |
| `POST /v1/auth/sign-in` | 200 com usuário e tokens; 401 `invalid_credentials` |
| `POST /v1/auth/refresh` | troca os dois tokens; 401 `invalid_refresh_token` |
| `POST /v1/auth/sign-out` | 204; o token deixa de valer |
| `GET /v1/tasks?status=active&limit=&cursor=` | as não arquivadas do usuário, das mais antigas, por cursor |
| `GET /v1/tasks/{id}` | a tarefa; 404 se não existe |
| `PUT /v1/tasks/{id}` | cria com o id do app (201, versão 1); a mesma operação de novo devolve a tarefa; outra operação no mesmo id é 409 `version_conflict` |
| `PATCH /v1/tasks/{id}` | altera ou arquiva com `baseVersion`; versão diferente é 409 `version_conflict`; operação já aplicada devolve a tarefa; 404 se não existe |

Toda rota de tarefa exige `Authorization: Bearer`; o token vencido recebe
401. O `Idempotency-Key` com o mesmo corpo recebe a resposta guardada, e
com outro corpo, 422 `idempotency_key_reused`. Títulos seguem a regra do
`TaskTitle`: espaços das pontas fora, de 1 a 200 pontos de código.

## "Outra pessoa"

| Rota | Para provocar |
| --- | --- |
| `POST /dev/tasks/{id}/edit` com `{"title"?, "status"?}` | um conflito de versão |
| `DELETE /dev/tasks/{id}` | uma tarefa apagada no servidor |
| `POST /dev/reject-next` com `{"status"?, "code"?}` | uma recusa que não é conflito (422 por padrão) |
| `POST /dev/omit-version-next` | uma resposta aceita sem a versão: o erro não fatal `tasks outbox response` no Crashlytics (capítulo 38) |
| `POST /dev/expire-tokens` | a renovação do token |
| `GET /dev/state`, `POST /dev/reset` | ver ou limpar o estado |

Os ids das tarefas são os UUIDs que o app gerou: pegue-os no
`GET /dev/state` e cole no lugar de `{id}`. Um id que não existe, como a
palavra `ID` colada por engano, recebe 404, e nada muda no servidor.

## Testes

`test/dev_backend_handler_test.dart` chama o handler direto, uma regra
por teste. `test/control_test.dart` fecha e abre a porta da API pela porta de
controle e confere a conexão recusada e o estado mantido.
`test/contract_test.dart` sobe o servidor numa porta livre e o
lê com o `HttpApiClient`, o `AuthModel`, o `RestAuthTokenService` e o
`RestTaskService` dos pacotes do app: se o backend se afastar do que o app
lê, o teste quebra antes do simulador.
