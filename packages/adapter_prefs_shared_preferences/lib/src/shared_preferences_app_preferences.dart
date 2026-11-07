import 'dart:async';

import 'package:core/core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [AppPreferences] com shared_preferences (`SharedPreferencesAsync`). Só
/// valores não sensíveis. Cada gravação também sai no stream de mudanças
/// correspondente, para o host aplicá-la sem reiniciar o app.
final class SharedPreferencesAppPreferences implements AppPreferences {
  SharedPreferencesAppPreferences({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _themeModeKey = 'app_preferences.theme_mode';
  static const _languageCodeKey = 'app_preferences.language_code';

  final SharedPreferencesAsync _preferences;
  final _themeModeChanges = StreamController<AppThemeMode>.broadcast();
  final _languageCodeChanges = StreamController<String>.broadcast();

  /// Um valor desconhecido (de uma versão futura, por exemplo) volta a
  /// [AppThemeMode.system].
  @override
  Future<AppThemeMode> themeMode() async {
    final stored = await _preferences.getString(_themeModeKey);
    return AppThemeMode.values.asNameMap()[stored] ?? AppThemeMode.system;
  }

  @override
  Future<void> saveThemeMode(AppThemeMode mode) async {
    await _preferences.setString(_themeModeKey, mode.name);
    _themeModeChanges.add(mode);
  }

  @override
  Stream<AppThemeMode> get themeModeChanges => _themeModeChanges.stream;

  @override
  Future<String?> languageCode() => _preferences.getString(_languageCodeKey);

  @override
  Future<void> saveLanguageCode(String languageCode) async {
    await _preferences.setString(_languageCodeKey, languageCode);
    _languageCodeChanges.add(languageCode);
  }

  @override
  Stream<String> get languageCodeChanges => _languageCodeChanges.stream;
}
