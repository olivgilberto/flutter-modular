/// Escolha de tema guardada pelo [AppPreferences]. Espelho em Dart puro do
/// `ThemeMode` do Flutter; o host faz a conversão.
enum AppThemeMode { system, light, dark }

/// Preferências não sensíveis (tema, idioma). Nunca tokens nem dados
/// pessoais ou de negócio. Os módulos só gravam; o host escuta as mudanças
/// e as aplica sem reiniciar o app.
abstract interface class AppPreferences {
  /// [AppThemeMode.system] até o usuário escolher.
  Future<AppThemeMode> themeMode();
  Future<void> saveThemeMode(AppThemeMode mode);
  Stream<AppThemeMode> get themeModeChanges;

  /// `null` até o usuário escolher um idioma: ele nunca é deduzido do
  /// idioma do sistema (capítulo 13).
  Future<String?> languageCode();
  Future<void> saveLanguageCode(String languageCode);
  Stream<String> get languageCodeChanges;
}
