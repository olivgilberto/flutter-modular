import 'package:flutter/widgets.dart';

/// As classes de largura de janela do Material 3.
enum WindowWidthClass { compact, medium, expanded, large, extraLarge }

/// As classes de altura de janela do Material 3.
enum WindowHeightClass { compact, medium, expanded }

/// O layout se adapta pela classe da janela, nunca pela orientação do
/// aparelho: um celular deitado e um tablet em pé podem cair na mesma
/// classe, e é a largura que decide.
abstract final class AppBreakpoints {
  /// Onde termina a classe compact. Também é a largura máxima de um
  /// formulário, que não se estica num tablet.
  static const compactMaxWidth = 600.0;

  static WindowWidthClass widthClassOf(BuildContext context) =>
      widthClassFor(MediaQuery.sizeOf(context).width);

  static WindowHeightClass heightClassOf(BuildContext context) =>
      heightClassFor(MediaQuery.sizeOf(context).height);

  static WindowWidthClass widthClassFor(double width) => switch (width) {
    < compactMaxWidth => WindowWidthClass.compact,
    < 840 => WindowWidthClass.medium,
    < 1200 => WindowWidthClass.expanded,
    < 1600 => WindowWidthClass.large,
    _ => WindowWidthClass.extraLarge,
  };

  static WindowHeightClass heightClassFor(double height) => switch (height) {
    < 480 => WindowHeightClass.compact,
    < 900 => WindowHeightClass.medium,
    _ => WindowHeightClass.expanded,
  };
}
