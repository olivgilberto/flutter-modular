import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../l10n/mobile_tarefas_localizations.dart';

/// O aviso de conexão abaixo de todas as telas (capítulos 12 e 33). O host
/// lê o estado no `ConnectivityService` do core e o traduz nos dois
/// parâmetros do `AppConnectivityBanner`; o banner não sabe o que é
/// conectividade. É só um aviso: a tela continua inteira e tocável, e
/// nenhuma ação depende dele.
///
/// Os textos são do host, nos ARB dele (capítulo 37). O host o põe pelo
/// `builder` do `MaterialApp.router`, que já está abaixo das traduções.
final class ConnectivityBannerHost extends StatelessWidget {
  const ConnectivityBannerHost({
    super.key,
    required this.connectivity,
    required this.child,
  });

  final ConnectivityService connectivity;
  final Widget child;

  @override
  Widget build(BuildContext context) => StreamBuilder<ConnectivityStatus>(
    stream: connectivity.statusChanges,
    initialData: connectivity.status,
    builder: (context, snapshot) {
      final status = snapshot.data ?? ConnectivityStatus.unknown;
      final message = messageFor(
        MobileTarefasLocalizations.of(context),
        status,
      );
      return Column(
        children: [
          Expanded(
            // Visível, o banner ocupa a margem de baixo da tela.
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: message != null,
              child: child,
            ),
          ),
          AppConnectivityBanner(
            visible: message != null,
            message: message ?? '',
          ),
        ],
      );
    },
  );

  /// `null` quando não há aviso: no início, antes da primeira verificação,
  /// e com o backend respondendo.
  @visibleForTesting
  static String? messageFor(
    MobileTarefasLocalizations l10n,
    ConnectivityStatus status,
  ) => switch (status) {
    ConnectivityStatus.unknown || ConnectivityStatus.online => null,
    ConnectivityStatus.offline => l10n.connectivityOffline,
    ConnectivityStatus.noInternet => l10n.connectivityNoInternet,
  };
}
