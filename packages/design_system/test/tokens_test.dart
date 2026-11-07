import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('todo estilo usa a Inter deste pacote', () {
    final t = AppTypography.textTheme;
    final styles = [
      t.displayLarge, t.displayMedium, t.displaySmall, //
      t.headlineLarge, t.headlineMedium, t.headlineSmall,
      t.titleLarge, t.titleMedium, t.titleSmall,
      t.bodyLarge, t.bodyMedium, t.bodySmall,
      t.labelLarge, t.labelMedium, t.labelSmall,
    ];

    for (final style in styles) {
      expect(style?.fontFamily, 'packages/design_system/Inter');
    }
  });

  test('o espaçamento segue a grade de 4 dp', () {
    const values = [
      AppSpacing.xs,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.xl,
      AppSpacing.xxl,
      AppSpacing.xxxl,
    ];
    for (final value in values) {
      expect(value % 4, 0, reason: '$value');
    }
  });

  test('as classes de largura seguem os limites do Material 3', () {
    expect(AppBreakpoints.widthClassFor(599), WindowWidthClass.compact);
    expect(AppBreakpoints.widthClassFor(600), WindowWidthClass.medium);
    expect(AppBreakpoints.widthClassFor(840), WindowWidthClass.expanded);
    expect(AppBreakpoints.widthClassFor(1200), WindowWidthClass.large);
    expect(AppBreakpoints.widthClassFor(1600), WindowWidthClass.extraLarge);
    expect(AppMargins.of(WindowWidthClass.compact), 16);
    expect(AppMargins.of(WindowWidthClass.medium), 24);
  });

  testWidgets('reduzir movimento encurta qualquer animação', (tester) async {
    late Duration resolved;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            resolved = AppMotionHelper.resolve(
              context,
              AppMotionDuration.long2,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    expect(resolved, const Duration(milliseconds: 1));
  });
}
