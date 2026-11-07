# design_system

A única fonte visual do app: os tokens do Material 3, o tema e os
componentes genéricos sobre os quais os módulos desenham as suas telas.

- **Contém:** cores (uma semente e as cores semânticas), tipografia Inter
  empacotada, elevação, espaçamento, breakpoints, forma, movimento, o
  `AppTheme` e componentes com nome visual (`AppEmptyState`,
  `AppConnectivityBanner`, `AppErrorPlaceholder`).
- **Nunca contém:** componentes com nome de negócio, textos ou traduções,
  leitura de preferências, Blocs, fontes ou imagens buscadas na rede, nem
  dependência do `core`, de um módulo ou de um adaptador.

A cor semente em `lib/tokens/app_color_scheme.dart` é provisória até a
definição da marca. A fonte Inter é distribuída sob a SIL Open Font
License 1.1 (`assets/fonts/OFL.txt`).
