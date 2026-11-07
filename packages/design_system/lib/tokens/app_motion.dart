import 'package:flutter/material.dart';

/// A escala de durações do Material 3.
abstract final class AppMotionDuration {
  static const short1 = Duration(milliseconds: 50);
  static const short2 = Duration(milliseconds: 100);
  static const short3 = Duration(milliseconds: 150);
  static const short4 = Duration(milliseconds: 200);
  static const medium1 = Duration(milliseconds: 250);
  static const medium2 = Duration(milliseconds: 300);
  static const medium3 = Duration(milliseconds: 350);
  static const medium4 = Duration(milliseconds: 400);
  static const long1 = Duration(milliseconds: 450);
  static const long2 = Duration(milliseconds: 500);
  static const long3 = Duration(milliseconds: 550);
  static const long4 = Duration(milliseconds: 600);
  static const extraLong1 = Duration(milliseconds: 700);
  static const extraLong2 = Duration(milliseconds: 800);
  static const extraLong3 = Duration(milliseconds: 900);
  static const extraLong4 = Duration(milliseconds: 1000);
}

/// As curvas oficiais do M3 que o Flutter já oferece, sem redeclarar os
/// valores. A `emphasized` não é uma cúbica simples: tem dois segmentos.
abstract final class AppMotionCurve {
  static const Curve standard = Easing.standard;
  static const Curve standardAccelerate = Easing.standardAccelerate;
  static const Curve standardDecelerate = Easing.standardDecelerate;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve emphasizedAccelerate = Easing.emphasizedAccelerate;
  static const Curve emphasizedDecelerate = Easing.emphasizedDecelerate;
}

abstract final class AppMotionHelper {
  /// Toda animação passa por aqui, nunca pela Duration crua: com "reduzir
  /// movimento" ligado no sistema, a animação praticamente some.
  static Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context)
      ? const Duration(milliseconds: 1)
      : duration;
}
