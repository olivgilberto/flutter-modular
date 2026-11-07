import 'package:flutter/material.dart';

/// Os estados que o `ColorScheme` não tem: crítico, positivo e neutro.
/// Cada par cor/onCor tem contraste AA (4,5:1) nos dois modos.
@immutable
final class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.critical,
    required this.onCritical,
    required this.positive,
    required this.onPositive,
    required this.neutral,
    required this.onNeutral,
  });

  final Color critical;
  final Color onCritical;
  final Color positive;
  final Color onPositive;
  final Color neutral;
  final Color onNeutral;

  static const light = AppSemanticColors(
    critical: Color(0xFFC35500),
    onCritical: Color(0xFFFFFFFF),
    positive: Color(0xFF188918),
    onPositive: Color(0xFFFFFFFF),
    neutral: Color(0xFF5B738B),
    onNeutral: Color(0xFFFFFFFF),
  );

  static const dark = AppSemanticColors(
    critical: Color(0xFFFFB300),
    onCritical: Color(0xFF000000),
    positive: Color(0xFF4CD964),
    onPositive: Color(0xFF000000),
    neutral: Color(0xFFA9B4BE),
    onNeutral: Color(0xFF000000),
  );

  /// Atalho para as Views: `AppSemanticColors.of(context).critical`.
  static AppSemanticColors of(BuildContext context) =>
      Theme.of(context).extension<AppSemanticColors>()!;

  @override
  AppSemanticColors copyWith({
    Color? critical,
    Color? onCritical,
    Color? positive,
    Color? onPositive,
    Color? neutral,
    Color? onNeutral,
  }) => AppSemanticColors(
    critical: critical ?? this.critical,
    onCritical: onCritical ?? this.onCritical,
    positive: positive ?? this.positive,
    onPositive: onPositive ?? this.onPositive,
    neutral: neutral ?? this.neutral,
    onNeutral: onNeutral ?? this.onNeutral,
  );

  /// Faz a transição suave quando o tema muda de claro para escuro.
  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      critical: Color.lerp(critical, other.critical, t)!,
      onCritical: Color.lerp(onCritical, other.onCritical, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      onPositive: Color.lerp(onPositive, other.onPositive, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      onNeutral: Color.lerp(onNeutral, other.onNeutral, t)!,
    );
  }
}
