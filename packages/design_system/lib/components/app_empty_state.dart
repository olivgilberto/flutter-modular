import 'package:flutter/material.dart';

import '../tokens/app_breakpoints.dart';
import '../tokens/app_margins.dart';
import '../tokens/app_spacing.dart';

/// Um estado vazio: ícone, título e mensagem opcional. Os textos chegam
/// prontos de quem o usa; o pacote não tem texto próprio.
final class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final margin = AppMargins.of(AppBreakpoints.widthClassOf(context));

    return Center(
      child: Padding(
        padding: EdgeInsets.all(margin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                icon,
                size: AppSpacing.xxxl,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (message case final message?) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
