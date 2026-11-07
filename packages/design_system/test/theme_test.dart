import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contrast.dart';

void main() {
  final themes = {'claro': AppTheme.light, 'escuro': AppTheme.dark};

  for (final MapEntry(key: mode, value: theme) in themes.entries) {
    group('tema $mode', () {
      test('traz as cores semânticas', () {
        expect(theme.extension<AppSemanticColors>(), isNotNull);
      });

      test('os pares de texto do ColorScheme passam no AA', () {
        final c = theme.colorScheme;
        final pairs = {
          'primary': (c.primary, c.onPrimary),
          'primaryContainer': (c.primaryContainer, c.onPrimaryContainer),
          'secondary': (c.secondary, c.onSecondary),
          'tertiary': (c.tertiary, c.onTertiary),
          'error': (c.error, c.onError),
          'surface': (c.surface, c.onSurface),
          'surfaceVariant': (c.surfaceContainerHighest, c.onSurfaceVariant),
          'inverseSurface': (c.inverseSurface, c.onInverseSurface),
        };
        for (final MapEntry(key: role, value: (bg, fg)) in pairs.entries) {
          expect(
            contrastRatio(bg, fg),
            greaterThanOrEqualTo(aaNormalText),
            reason: role,
          );
        }
      });

      test('as cores semânticas passam no AA', () {
        final s = theme.extension<AppSemanticColors>()!;
        expect(contrastRatio(s.critical, s.onCritical), greaterThan(4.5));
        expect(contrastRatio(s.positive, s.onPositive), greaterThan(4.5));
        expect(contrastRatio(s.neutral, s.onNeutral), greaterThan(4.5));
      });
    });
  }

  test('o brilho de cada tema é o do nome', () {
    expect(AppTheme.light.colorScheme.brightness, Brightness.light);
    expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
  });

  test('a transição entre os modos interpola as cores semânticas', () {
    final middle = AppSemanticColors.light.lerp(AppSemanticColors.dark, 0.5);

    expect(middle.critical, isNot(AppSemanticColors.light.critical));
    expect(middle.critical, isNot(AppSemanticColors.dark.critical));
  });
}
