import 'package:flutter/material.dart';

import '../tokens/app_breakpoints.dart';
import '../tokens/app_margins.dart';
import '../tokens/app_motion.dart';
import '../tokens/app_spacing.dart';

/// O aviso de conexão, nunca um modal. Puramente visual: o host decide
/// quando ele aparece ([visible]) e entrega a [message] já traduzida. Entra
/// e sai com os tokens de movimento, respeitando "reduzir movimento", e é
/// anunciado pelos leitores de tela.
final class AppConnectivityBanner extends StatelessWidget {
  const AppConnectivityBanner({
    super.key,
    required this.visible,
    required this.message,
  });

  final bool visible;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final margin = AppMargins.of(AppBreakpoints.widthClassOf(context));

    return AnimatedSize(
      duration: AppMotionHelper.resolve(context, AppMotionDuration.medium2),
      curve: AppMotionCurve.standard,
      alignment: Alignment.topCenter,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Material(
              color: colors.inverseSurface,
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AppSpacing.xxxl),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: margin,
                      vertical: AppSpacing.sm,
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Row(
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              Icons.cloud_off_outlined,
                              color: colors.onInverseSurface,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              message,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: colors.onInverseSurface),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
