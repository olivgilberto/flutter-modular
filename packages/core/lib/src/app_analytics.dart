/// Eventos de produto (capítulo 14).
abstract interface class AppAnalytics {
  /// Um evento de produto: [name] segue `[módulo]_[objeto]_[ação]`.
  /// Valores de [parameters] são String ou num, nunca dados pessoais.
  Future<void> logEvent(String name, [Map<String, Object> parameters]);

  /// A tela que o usuário abriu (chamado pelo host, nunca por módulo).
  Future<void> logScreenView(String screenName);
}
