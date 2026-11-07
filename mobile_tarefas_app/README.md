# mobile_tarefas_app

O host do mobile_tarefas: o único pacote do workspace que gera um
aplicativo, para Android e iOS, e o único que depende dos pacotes
`adapter_*`. Ele liga cada porta do `core` ao seu adaptador no composition
root (`lib/bootstrap/dependency_injection.dart`) e reúne os módulos de
feature. Não contém regra de negócio.

Arquitetura: [`../docs/architecture.md`](../docs/architecture.md).

## Situação

- `auth_module` ligado (capítulo 28): sem sessão, o app abre no login;
  com sessão, na lista do `tasks_module` (capítulo 34), dentro da
  moldura do host com o botão de sair. O estado da sessão vem do
  `SessionBloc` do módulo, observado pelo `SessionGate`
  (`lib/session/`), que abre e fecha o escopo da sessão.
- Boot em `lib/bootstrap/boot.dart` (capítulo 25): cada passo assíncrono
  tem tempo limite e caminho alternativo. Roteador em
  `lib/bootstrap/app_router.dart`; tema e idioma em `lib/settings/`.
- Três flavors (capítulo 26): `dev`, `staging` e `prod`, com um
  `lib/main_[flavor].dart` e um `config/[flavor].json` para cada um. Os
  identificadores e nomes na tela estão em `android/app/build.gradle.kts`,
  `android/app/src/[flavor]/res/values/strings.xml` e nos xcconfigs que
  `tool/configure_ios_flavors.rb` gera em `ios/Flutter/`.
- Ícone por flavor: quando o produto tiver um ícone (decisão registrada).
- Firebase ainda não configurado: o passo 1 do boot falha e o app segue;
  os adaptadores de logging e analytics escrevem no console até o
  `flutterfire configure` (capítulo 38).
- O `SyncScheduler` (workmanager) é registrado junto com o dispatcher de
  sincronização em segundo plano, no capítulo 32.

## Rodar

Sempre com os três parâmetros do flavor, que precisam concordar (o app
confere na abertura):

```sh
cd mobile_tarefas_app
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=config/dev.json
```

Para `staging` e `prod`, troque o nome nos três lugares.

### Com o backend local (capítulo 35)

Sem backend de verdade, o flavor `dev` roda contra o
`tools/dev_backend`, um servidor em memória que segue o contrato. Num
terminal, da raiz do workspace:

```sh
dart run tools/dev_backend/bin/dev_backend.dart
```

Em outro, o app com o `config/dev_local.json`:

```sh
cd mobile_tarefas_app
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=config/dev_local.json
```

O simulador do iOS alcança o `127.0.0.1` do computador. No emulador do
Android, rode antes `adb reverse tcp:8080 tcp:8080`. O http sem TLS só é
aceito no flavor `dev` e só na interface local; parar o servidor apaga
contas e tarefas.

## Verificar

Da raiz do workspace:

```sh
dart run melos run analyze
dart run melos run test
dart run melos run check-deps
```

## Testes de integração (capítulo 39)

Em `integration_test/`, rodam no aparelho: o caminho feliz, o fluxo
offline e os adaptadores com a tecnologia de verdade. Com um emulador do
Android ligado (o simulador do iOS o script liga sozinho) e as portas
8080 e 8081 livres:

```sh
bash code/verificar_integracao.sh            # as duas plataformas
PLATFORMS=ios FILES=offline_test.dart bash code/verificar_integracao.sh
```

O script sobe o `dev_backend` com `--control-port 8081`, liga as portas
ao emulador com o `adb reverse` e roda cada arquivo num app instalado do
zero. Os testes montam o app pelo `mainCommon`, sem Firebase, sem os
handlers globais e sem o pedido de rastreamento.
