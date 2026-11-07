import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import 'app_languages.dart';

/// O tema e o idioma que o host aplica ao app. Lidos uma vez no boot e
/// atualizados a cada gravação na `AppPreferences`, de qualquer módulo, sem
/// reiniciar o app. O roteador escuta este objeto para o redirect.
final class AppSettings extends ChangeNotifier {
  AppSettings._({
    required AppPreferences preferences,
    required AppThemeMode themeMode,
    required Locale? locale,
  }) : _preferences = preferences,
       _themeMode = themeMode,
       _locale = locale {
    _subscriptions = [
      preferences.themeModeChanges.listen((mode) {
        _themeMode = mode;
        notifyListeners();
      }),
      preferences.languageCodeChanges.listen((tag) {
        _locale = AppLanguages.fromTag(tag);
        notifyListeners();
      }),
    ];
  }

  /// Passo 5 do boot. Cada leitura tem tempo limite e um valor padrão: sem
  /// a preferência, o tema segue o sistema e o idioma fica por escolher.
  static Future<AppSettings> load({
    required AppPreferences preferences,
    required AppLogger logger,
    required Duration timeout,
  }) async {
    var themeMode = AppThemeMode.system;
    Locale? locale;
    try {
      themeMode = await preferences.themeMode().timeout(timeout);
      locale = AppLanguages.fromTag(
        await preferences.languageCode().timeout(timeout),
      );
    } on Exception catch (error, stackTrace) {
      // TimeoutException ou uma falha do plugin: o app abre com os padrões.
      logger.error('boot preferences', error, stackTrace);
    }
    return AppSettings._(
      preferences: preferences,
      themeMode: themeMode,
      locale: locale,
    );
  }

  final AppPreferences _preferences;
  late final List<StreamSubscription<Object>> _subscriptions;
  AppThemeMode _themeMode;
  Locale? _locale;

  ThemeMode get themeMode => switch (_themeMode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  /// `null` enquanto o usuário não escolheu: o redirect leva à escolha.
  Locale? get locale => _locale;

  /// Só grava; quem aplica é o stream de mudanças, o mesmo caminho de uma
  /// troca feita por uma tela de configurações de qualquer módulo.
  Future<void> chooseLanguage(Locale locale) =>
      _preferences.saveLanguageCode(locale.toLanguageTag());

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
