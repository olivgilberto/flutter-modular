import 'package:flutter/material.dart';

/// Todas as cores de papel (primária, superfícies, erro, contorno...) saem
/// de uma única semente. Nenhum outro hexadecimal de papel existe no app.
abstract final class AppColorScheme {
  /// Provisória até a definição da marca: mudar só este valor recalcula
  /// todas as outras cores, em claro e escuro.
  static const _brandSeed = Color(0xFF2F6EEA);

  /// `fidelity` mantém a cor da marca reconhecível; o padrão `tonalSpot`
  /// a dessaturaria. Contraste 0,5 é o médio do Material.
  static final light = ColorScheme.fromSeed(
    seedColor: _brandSeed,
    brightness: Brightness.light,
    contrastLevel: 0.5,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );

  static final dark = ColorScheme.fromSeed(
    seedColor: _brandSeed,
    brightness: Brightness.dark,
    contrastLevel: 0.5,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
}
