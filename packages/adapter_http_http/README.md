# adapter_http_http

O acesso HTTP do projeto, com o pacote `http` do time do Dart. Substituiu o
`adapter_http_dio` no capítulo 41.

- **Contém:** `HttpApiClient` (porta `ApiClient`), com o token e a renovação
  diante de um 401 no próprio envio, a nova tentativa pelo `RetryClient` do
  pacote e o log e o tempo limite de cada tentativa; e `HttpReachabilityProbe`
  (porta `ReachabilityProbe`).
- **Nunca contém:** endpoints, modelos ou regras de um módulo, nem o
  registro no get_it (quem o constrói é o host). Nenhum tipo do pacote http
  sai deste pacote: toda falha vira `ApiError`.
