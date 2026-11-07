import 'package:flutter/material.dart';

import '../tokens/app_spacing.dart';

/// O que o `ErrorWidget.builder` do host devolve quando um widget falha ao
/// construir: um ícone neutro, sem texto. Pode ser construído sem
/// localização e até sem `Directionality`, então não depende de nenhum dos
/// dois; a falha em si vai para o `AppLogger` pelo handler do host.
final class AppErrorPlaceholder extends StatelessWidget {
  const AppErrorPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: AppSpacing.xxl,
          color: colors.onSurfaceVariant,
          textDirection: TextDirection.ltr,
        ),
      ),
    );
  }
}
