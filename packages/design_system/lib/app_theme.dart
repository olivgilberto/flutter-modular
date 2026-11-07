import 'package:flutter/material.dart';

import 'tokens/app_color_scheme.dart';
import 'tokens/app_semantic_colors.dart';
import 'tokens/app_shape.dart';
import 'tokens/app_typography.dart';

/// O único `ThemeData` do app. O host escolhe entre [light] e [dark] com o
/// tema que o usuário guardou na porta `AppPreferences`; este pacote nunca
/// lê nem grava preferências.
abstract final class AppTheme {
  static ThemeData get light => _build(
    colorScheme: AppColorScheme.light,
    semanticColors: AppSemanticColors.light,
  );

  static ThemeData get dark => _build(
    colorScheme: AppColorScheme.dark,
    semanticColors: AppSemanticColors.dark,
  );

  static ThemeData _build({
    required ColorScheme colorScheme,
    required AppSemanticColors semanticColors,
  }) => ThemeData(
    colorScheme: colorScheme,
    textTheme: AppTypography.textTheme,
    extensions: [semanticColors],
    cardTheme: const CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.medium),
    ),
  );
}
