import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../settings/app_languages.dart';

/// A escolha de idioma no primeiro uso (capítulo 13). Cada idioma aparece
/// no próprio idioma, então a tela não tem nada a traduzir.
final class LanguageSelectionPage extends StatelessWidget {
  const LanguageSelectionPage({super.key, required this.onSelected});

  final ValueChanged<Locale> onSelected;

  @override
  Widget build(BuildContext context) {
    return AppForm(
      title: 'Idioma · Language',
      children: [
        for (final language in AppLanguages.all)
          AppPrimaryButton(
            label: language.nativeName,
            onPressed: () => onSelected(language.locale),
          ),
      ],
    );
  }
}
