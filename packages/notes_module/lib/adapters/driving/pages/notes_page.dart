import 'package:flutter/material.dart';

import '../l10n/notes_module_localizations.dart';

/// A única tela do rascunho.
final class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = NotesModuleLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notesTitle)),
      body: Center(child: Text(l10n.notesEmpty)),
    );
  }
}
