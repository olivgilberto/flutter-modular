import 'package:auth_module/auth_module.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// A moldura das telas de quem entrou (capítulo 29): a tela do módulo de
/// feature e, abaixo dela, o botão de sair do auth_module. Desde o
/// capítulo 34, a moldura envolve as rotas do módulo de tarefas e ocupa o
/// lugar da tela inicial provisória. O host monta a moldura; o módulo de
/// tarefas não conhece o auth_module.
final class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(child: child),
      Material(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: const LogoutButton(),
          ),
        ),
      ),
    ],
  );
}
