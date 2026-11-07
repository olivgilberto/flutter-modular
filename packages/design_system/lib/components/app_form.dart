import 'package:flutter/material.dart';

import '../tokens/app_breakpoints.dart';
import '../tokens/app_margins.dart';
import '../tokens/app_spacing.dart';

/// Uma tela de formulário: barra com o [title], área segura, rolagem e uma
/// coluna que não passa da largura da classe compact, para que os campos
/// não se estiquem num tablet. Os [children] ficam num `AutofillGroup`,
/// então o gerenciador de senhas do sistema preenche e salva os campos
/// juntos.
final class AppForm extends StatelessWidget {
  const AppForm({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final margin = AppMargins.of(AppBreakpoints.widthClassOf(context));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(margin),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppBreakpoints.compactMaxWidth,
              ),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.lg,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
