import 'package:flutter/widgets.dart';

/// Um idioma que o app oferece, com o nome escrito no próprio idioma: a
/// tela de escolha não precisa de tradução (capítulo 13).
typedef AppLanguage = ({Locale locale, String nativeName});

/// Os idiomas do produto. Quais idiomas o app oferece é decisão do host;
/// cada módulo traz as próprias traduções (capítulo 37).
abstract final class AppLanguages {
  static const all = <AppLanguage>[
    (locale: Locale('pt', 'BR'), nativeName: 'Português (Brasil)'),
    (locale: Locale('en'), nativeName: 'English'),
  ];

  static final supported = [for (final language in all) language.locale];

  /// O idioma dos ARB template dos módulos. Só é usado enquanto o usuário
  /// ainda não escolheu, para os textos internos do Material: o `locale` do
  /// app nunca é nulo, porque nulo seria o idioma do sistema.
  static const template = Locale('en');

  /// O idioma guardado pela `AppPreferences`, como etiqueta BCP 47
  /// ('pt-BR', 'en'). Uma etiqueta que o app não oferece conta como "ainda
  /// não escolhido".
  static Locale? fromTag(String? tag) {
    for (final locale in supported) {
      if (locale.toLanguageTag() == tag) return locale;
    }
    return null;
  }
}
