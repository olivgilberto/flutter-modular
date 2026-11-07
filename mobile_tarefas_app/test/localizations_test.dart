import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_tarefas_app/app.dart';
import 'package:mobile_tarefas_app/l10n/mobile_tarefas_localizations.dart';
import 'package:mobile_tarefas_app/settings/app_languages.dart';

/// Quais idiomas o app oferece é decisão do host; traduzir as telas é de
/// cada módulo (capítulo 37). Este teste cobre o espaço entre as duas
/// coisas: um módulo novo que só traga inglês não passa daqui.
void main() {
  test('todo delegate traduz todos os idiomas do app', () {
    for (final locale in AppLanguages.supported) {
      for (final delegate in [
        MobileTarefasLocalizations.delegate,
        ...moduleLocalizationsDelegates,
      ]) {
        expect(
          delegate.isSupported(locale),
          isTrue,
          reason: '${delegate.type} sem $locale',
        );
      }
    }
  });

  test('cada delegate carrega em todos os idiomas do app', () async {
    for (final locale in AppLanguages.supported) {
      for (final delegate in appLocalizationsDelegates) {
        await expectLater(delegate.load(locale), completes, reason: '$locale');
      }
    }
  });

  test('o idioma do template, usado só antes da escolha, é um dos '
      'oferecidos', () {
    expect(AppLanguages.supported, contains(AppLanguages.template));
  });

  test('o português do Brasil cai no ARB "pt"', () {
    final l10n = lookupMobileTarefasLocalizations(const Locale('pt', 'BR'));
    expect(l10n.appTitle, 'Tarefas');
  });
}
