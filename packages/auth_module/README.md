# auth_module

A autenticação do mobile_tarefas: login com e-mail e senha, cadastro,
sessão restaurada no boot, logout com limpeza dos dados de todos os
módulos e sessão expirada.

- **Contém:** o domínio (`User`, `EmailAddress`, `Password`, a família
  `AuthFailure`), a aplicação (a porta `AuthRepository` e o
  `AuthUseCase`), os adaptadores driven (capítulo 21) e os driving
  (capítulo 22): as telas de login e cadastro e a lista `authModuleRoutes`,
  que o host espalha no seu `GoRouter`, e o `SessionBloc` (capítulo 28),
  o estado da sessão que o host observa. Desde o capítulo 32, o dono dos
  dados guardados no aparelho, gravado no `auth.db`.
- **Nunca contém:** dependência de outro módulo ou de um pacote
  `adapter_*`, nem tecnologia que o `core` abstrai. O token chega aos
  outros módulos pela porta `TokenProvider` do `core`.

Documentação: `docs/modules/auth_module.md`.
