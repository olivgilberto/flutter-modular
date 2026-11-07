/// Implementada pelo módulo de autenticação; usada pelo adaptador HTTP sem
/// que nenhum dos dois conheça o outro (capítulo 11).
abstract interface class TokenProvider {
  /// O token da sessão atual, ou `null` se não há sessão.
  Future<String?> currentToken();

  /// Chamado quando o servidor recusou o token atual. Devolve um token
  /// novo, ou `null` quando a sessão não pode ser renovada; nesse caso,
  /// a implementação avisa que a sessão expirou.
  ///
  /// Chamadas simultâneas compartilham a mesma renovação.
  Future<String?> refreshToken();
}
