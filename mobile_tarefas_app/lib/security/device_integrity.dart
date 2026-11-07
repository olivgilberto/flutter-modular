import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safe_device/safe_device.dart';

import '../l10n/mobile_tarefas_localizations.dart';

/// A verificação de root e jailbreak (capítulos 14 e 38): avisar, não
/// expulsar. A detecção é contornável por quem quer contorná-la, e bloquear
/// o app pune sobretudo quem modificou o aparelho por outros motivos. O
/// mobile_tarefas não tem funcionalidade sensível para desligar, então fica
/// só o aviso.
///
/// Emuladores e simuladores ficam de fora: são o ambiente de
/// desenvolvimento, e costumam parecer aparelhos com root.
Future<bool> deviceCompromised({
  required AppLogger logger,
  Future<bool> Function() isRealDevice = _isRealDevice,
  Future<bool> Function() isJailBroken = _isJailBroken,
}) async {
  try {
    if (!await isRealDevice()) return false;
    final compromised = await isJailBroken();
    if (compromised) logger.log('device integrity: root or jailbreak');
    return compromised;
  } on PlatformException catch (error, stackTrace) {
    // Na dúvida, nenhum aviso: um falso positivo assusta sem motivo.
    logger.error('device integrity', error, stackTrace);
    return false;
  }
}

/// O aviso, no alto da tela, até o usuário dispensá-lo. Não bloqueia nada:
/// a tela continua inteira e tocável abaixo dele.
void showDeviceIntegrityNotice(ScaffoldMessengerState messenger) {
  final l10n = MobileTarefasLocalizations.of(messenger.context);
  messenger.showMaterialBanner(
    MaterialBanner(
      leading: const Icon(Icons.gpp_maybe_outlined),
      content: Text(l10n.deviceIntegrityWarning),
      actions: [
        TextButton(
          onPressed: messenger.hideCurrentMaterialBanner,
          child: Text(l10n.deviceIntegrityDismiss),
        ),
      ],
    ),
  );
}

Future<bool> _isRealDevice() => SafeDevice.isRealDevice;

Future<bool> _isJailBroken() => SafeDevice.isJailBroken;
