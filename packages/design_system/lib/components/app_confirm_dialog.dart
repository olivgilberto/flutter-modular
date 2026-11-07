import 'package:flutter/material.dart';

/// Pede ao usuário que confirme uma ação que não tem volta, como sair com
/// alterações não enviadas. Devolve `true` só quando ele confirma; fechar o
/// diálogo de qualquer outro jeito conta como desistir. Os textos chegam
/// prontos, já traduzidos, como em todo componente do pacote.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      // Com a fonte do sistema grande, o título e a mensagem passam da
      // altura da tela; rolando, os botões continuam ao alcance
      // (capítulo 39).
      scrollable: true,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
