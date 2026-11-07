# workspace_lints

Ferramentas do repositório, nunca dependência de outro pacote.

- `bin/check_dependencies.dart`: lê o `pubspec.yaml` de cada membro do
  workspace e confere a seção `dependencies` contra a regra do papel que o
  nome do pacote declara (capítulo 15 do livro). Rodado pelo script
  `check-deps` do Melos, na raiz.
  Desde o capítulo 42, confere também os registros de cada módulo de
  feature (`lib/src/module_records.dart`): a página em `docs/modules/`, a
  linha no índice "Módulos" do `docs/architecture.md` e uma linha própria
  no `.github/CODEOWNERS` (a última que alcança o módulo, como no GitHub);
  e recusa uma página de módulo que não está no workspace.
- `lib/main.dart`: o plugin do analisador (capítulo 40), declarado no
  `analysis_options.yaml` da raiz, com duas regras de lint:
  - `get_it_outside_edges`: o `get_it` só em `lib/bootstrap/` (o
    composition root do host), em `lib/[pacote].dart` (a entrada de cada
    módulo), em `lib/adapters/driving/pages/` e fora de `lib/` (testes);
  - `layer_imports`: domínio sem aplicação, adaptadores ou Flutter;
    aplicação sem adaptadores ou Flutter; driving sem driven nem
    `application/ports/`; driven sem driving.
  As violações aparecem na IDE e no `dart analyze` da raiz. Os testes, em
  `test/rules/`, usam o `analyzer_testing`: para cada regra, arquivos que
  violam e arquivos que não violam.
