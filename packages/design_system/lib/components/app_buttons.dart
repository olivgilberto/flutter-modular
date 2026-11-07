import 'package:flutter/material.dart';

import '../tokens/app_spacing.dart';

/// A ação principal da tela. Com [loading], o botão fica desabilitado e
/// mostra o indicador ao lado do rótulo, que continua visível: o leitor de
/// tela segue anunciando o que o botão faz.
final class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSpacing.xxxl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading) ...[
            const ExcludeSemantics(
              child: SizedBox.square(
                dimension: AppSpacing.lg,
                child: CircularProgressIndicator(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}

/// Uma ação secundária, como um link para outra tela.
final class AppTextButton extends StatelessWidget {
  const AppTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSpacing.xxxl),
      ),
      child: Text(label),
    );
  }
}
