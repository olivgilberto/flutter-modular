import 'package:flutter/material.dart';

import '../tokens/app_spacing.dart';

/// Uma mensagem de erro dentro da tela, perto do que a provocou. Recebe o
/// texto pronto e é anunciada pelo leitor de tela quando aparece.
final class AppInlineError extends StatelessWidget {
  const AppInlineError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(Icons.error_outline, color: theme.colorScheme.error),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
