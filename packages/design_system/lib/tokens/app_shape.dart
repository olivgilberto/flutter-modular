import 'package:flutter/painting.dart';

/// Os sete níveis de raio do Material 3.
abstract final class AppShape {
  static const none = 0.0;
  static const extraSmall = 4.0;
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const extraLarge = 28.0;

  /// Pílula ou círculo.
  static const full = 999.0;
}

abstract final class AppBorderRadius {
  static const none = BorderRadius.zero;
  static const extraSmall = BorderRadius.all(
    Radius.circular(AppShape.extraSmall),
  );
  static const small = BorderRadius.all(Radius.circular(AppShape.small));
  static const medium = BorderRadius.all(Radius.circular(AppShape.medium));
  static const large = BorderRadius.all(Radius.circular(AppShape.large));
  static const extraLarge = BorderRadius.all(
    Radius.circular(AppShape.extraLarge),
  );
  static const full = BorderRadius.all(Radius.circular(AppShape.full));
}
