import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_tarefas_app/settings/app_settings.dart';

import '../support/fakes.dart';

void main() {
  late FakeLogger logger;

  setUp(() => logger = FakeLogger());

  Future<AppSettings> load(FakePreferences preferences) => AppSettings.load(
    preferences: preferences,
    logger: logger,
    timeout: const Duration(milliseconds: 50),
  );

  test('lê o tema e o idioma guardados', () async {
    final settings = await load(
      FakePreferences(
        storedThemeMode: AppThemeMode.dark,
        storedLanguage: 'pt-BR',
      ),
    );
    addTearDown(settings.dispose);

    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.locale, const Locale('pt', 'BR'));
  });

  test('um idioma que o app não oferece conta como não escolhido', () async {
    final settings = await load(FakePreferences(storedLanguage: 'fr'));
    addTearDown(settings.dispose);

    expect(settings.locale, isNull);
  });

  test('uma leitura presa não trava o boot: valem os padrões', () async {
    final settings = await load(FakePreferences(hang: true));
    addTearDown(settings.dispose);

    expect(settings.themeMode, ThemeMode.system);
    expect(settings.locale, isNull);
    expect(logger.errors, ['boot preferences']);
  });

  test('a escolha grava pela porta e volta pelo stream, avisando quem '
      'escuta', () async {
    final preferences = FakePreferences();
    final settings = await load(preferences);
    addTearDown(settings.dispose);
    var notified = 0;
    settings.addListener(() => notified++);

    await settings.chooseLanguage(const Locale('en'));
    await preferences.saveThemeMode(AppThemeMode.light);
    // Os streams de mudança entregam os eventos de forma assíncrona.
    await Future<void>.delayed(Duration.zero);

    expect(preferences.storedLanguage, 'en');
    expect(settings.locale, const Locale('en'));
    expect(settings.themeMode, ThemeMode.light);
    expect(notified, 2);
  });
}
