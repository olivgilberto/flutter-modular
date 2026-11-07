import 'package:flutter/painting.dart';

/// Cinco níveis de sombra. A elevação do M3 combina três técnicas: o tom
/// da superfície (os `surfaceContainer*` do `ColorScheme`), esta sombra e o
/// [AppScrim]; nunca só a sombra.
abstract final class AppElevation {
  /// Superfície no plano base.
  static const level0 = <BoxShadow>[];
  static const level1 = <BoxShadow>[
    BoxShadow(color: Color(0x21000000), blurRadius: 2),
    BoxShadow(color: Color(0x0A000000), offset: Offset(0, 1), blurRadius: 4),
  ];

  /// Cartões.
  static const level2 = <BoxShadow>[
    BoxShadow(color: Color(0x21000000), blurRadius: 2),
    BoxShadow(color: Color(0x0A000000), offset: Offset(0, 2), blurRadius: 8),
  ];

  /// Avisos e menus.
  static const level3 = <BoxShadow>[
    BoxShadow(color: Color(0x21000000), blurRadius: 2),
    BoxShadow(color: Color(0x0A000000), offset: Offset(0, 8), blurRadius: 16),
  ];

  /// Popovers e o elemento em destaque.
  static const level4 = <BoxShadow>[
    BoxShadow(color: Color(0x21000000), blurRadius: 2),
    BoxShadow(color: Color(0x0A000000), offset: Offset(0, 14), blurRadius: 28),
  ];
}

/// A camada semitransparente que separa um modal do resto da tela.
abstract final class AppScrim {
  static const color = Color(0x8A000000);
}
