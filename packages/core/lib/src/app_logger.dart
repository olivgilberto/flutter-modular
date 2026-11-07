/// O registro de falhas (capítulo 14).
abstract interface class AppLogger {
  /// Um passo que ajuda a entender uma falha futura (breadcrumb).
  /// Nunca dados pessoais, tokens, cabeçalhos ou corpos.
  void log(String message);

  /// Um erro tratado, que não derrubou o app. [reason] diz onde
  /// aconteceu e não leva valores únicos (ids, datas).
  void error(String reason, Object error, StackTrace stackTrace);

  /// Um erro que ninguém tratou: o app pode estar inconsistente.
  void fatal(Object error, StackTrace stackTrace);

  /// Um identificador opaco da conta, ou `null` no logout.
  void setUserId(String? opaqueId);
}
