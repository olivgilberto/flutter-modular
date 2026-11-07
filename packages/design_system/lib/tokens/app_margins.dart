import 'app_breakpoints.dart';

/// As margens laterais vêm da classe de largura, nunca de um valor fixo.
abstract final class AppMargins {
  static const compact = 16.0;
  static const wide = 24.0;

  static double of(WindowWidthClass widthClass) => switch (widthClass) {
    WindowWidthClass.compact => compact,
    WindowWidthClass.medium ||
    WindowWidthClass.expanded ||
    WindowWidthClass.large ||
    WindowWidthClass.extraLarge => wide,
  };
}
