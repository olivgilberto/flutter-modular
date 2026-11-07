# Flutter Modular: o código do livro

Este repositório traz o `mobile_tarefas`, o app construído na Parte II do livro
**Flutter Modular: Portas, adaptadores, DDD e monorepos com Dart e Flutter: do
workspace ao CI/CD, com offline-first e testes**, de Gilberto Oliveira.

O código está no estado em que o livro termina, no capítulo 43, e foi verificado
com o **Flutter 3.47.5** em novembro de 2026. A tag `edicao-1` marca exatamente
esse estado; a branch `main` pode receber correções depois.

## O que tem aqui

```
mobile_tarefas_app/   o app host: composition root, boot, rotas, flavors (cap. 24 a 29)
packages/core/        as portas, em Dart puro e sem dependências (cap. 17)
packages/adapter_*/   os sete adaptadores, um por tecnologia (cap. 18 e 41)
packages/design_system/
packages/auth_module/ o módulo de autenticação (cap. 20 a 23 e 28)
packages/tasks_module/ o módulo de tarefas, offline-first (cap. 30 a 36)
tools/workspace_lints/ o check-deps e o plugin das fronteiras (cap. 15, 16 e 40)
tools/dev_backend/    o backend local de desenvolvimento (cap. 35)
docs/                 a documentação de arquitetura (Apêndice E)
```

Para saber em que arquivos cada capítulo trabalha, use o Apêndice G do livro, que
mapeia cada capítulo pela região da arquitetura e pelo pacote.

## Como rodar

Você precisa do Flutter 3.47.5 (versões posteriores podem pedir ajustes pequenos),
do Xcode para o iOS (só no macOS) e do Android Studio ou das ferramentas de linha de
comando do Android.

```sh
# na raiz: resolve o workspace inteiro
flutter pub get

# traduções de cada pacote (capítulo 37)
for p in $(grep -oE '^  - [^ ]+' pubspec.yaml | sed 's/^  - //'); do
  [ -f "$p/l10n.yaml" ] && (cd "$p" && flutter gen-l10n)
done

# verificações do workspace (capítulos 15 e 40)
dart run melos run analyze --no-select
dart run melos run check-deps --no-select
dart run melos run test --no-select
```

Para usar o app de verdade, rode o backend local num terminal e o app em outro
(capítulo 35):

```sh
# terminal A, na raiz
dart run tools/dev_backend/bin/dev_backend.dart

# terminal B, em mobile_tarefas_app/
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=config/dev_local.json
```

No emulador do Android, ligue a porta do backend antes: `adb reverse tcp:8080 tcp:8080`.

## Firebase (capítulo 38)

Os arquivos do Firebase não fazem parte deste repositório: eles apontam para um
projeto do Firebase, e cada leitor cria o seu. Sem eles, o app compila e roda
normalmente, e os adaptadores de logging e analytics escrevem no console.

Para ligar o Crashlytics e o Analytics, siga o capítulo 38 (e o 40 para staging e
prod): crie um projeto por flavor, rode o `flutterfire configure` para cada um e
troque o corpo de `mobile_tarefas_app/lib/bootstrap/firebase_options.dart` pelo do
livro, que está no comentário do próprio arquivo. Os arquivos gerados já estão no
`.gitignore`. Troque também o identificador `com.zayitbrazil.mobiletarefas` pelo
seu (capítulo 26).

## Diferenças em relação ao livro

Para que o repositório funcione sem o Firebase e sem segredos, cinco arquivos têm
um pequeno ajuste, marcado com o comentário "Cópia pública do livro":

| Arquivo | No livro | Aqui |
| --- | --- | --- |
| `mobile_tarefas_app/lib/bootstrap/firebase_options.dart` | as opções de cada flavor | `null` para todos, até o `flutterfire configure` |
| `mobile_tarefas_app/lib/bootstrap/boot.dart` | sem opções, o Firebase procura a configuração nativa | sem opções, o Firebase não é chamado |
| `mobile_tarefas_app/android/app/build.gradle.kts` | plugins do Firebase sempre aplicados | aplicados só quando existe um `google-services.json` |
| `mobile_tarefas_app/ios/Runner.xcodeproj/project.pbxproj` | a fase do FlutterFire sempre roda | pula, com um aviso, sem o `firebase.json` |
| `.github/workflows/ci.yml` | o build de release roda em todo push na main | roda só quando os segredos da chave de upload existem |

O teste `test/bootstrap/firebase_options_test.dart` confere o comportamento sem o
Firebase.

## Branches de demonstração

- `demo/fronteiras`: o módulo de tarefas importa o `auth_module` e o `get_it` no
  domínio, de propósito. O CI dessa branch falha, e é esse o ponto: o workspace
  recusa a violação (capítulos 15 e 36).
- `cap42/esqueleto`: o rascunho do `notes_module`, criado pelo checklist do
  capítulo 28, como no capítulo 42. Não entra na `main`.

## Erros e dúvidas

Encontrou um erro no código ou no livro? Abra uma issue, dizendo o capítulo e a
seção.

## Licença

O código está sob a licença MIT (arquivo `LICENSE`). O texto do livro não faz parte
deste repositório e tem todos os direitos reservados. As fontes Inter, em
`packages/design_system/assets/fonts`, seguem a SIL Open Font License (`OFL.txt`).
