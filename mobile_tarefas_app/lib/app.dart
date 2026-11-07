import 'package:auth_module/auth_module.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:tasks_module/tasks_module.dart';

import 'connectivity/connectivity_banner_host.dart';
import 'l10n/mobile_tarefas_localizations.dart';
import 'settings/app_languages.dart';
import 'settings/app_settings.dart';

/// O app: o tema do design_system, o idioma e o tema escolhidos pelo
/// usuário, o roteador do host e, abaixo de todas as telas, o aviso de
/// conexão (capítulo 33). As traduções (capítulo 37): o host junta o
/// delegate de cada módulo ao seu e aos do Flutter; cada módulo traduz as
/// próprias telas, e o host só decide os idiomas e qual está valendo.
final class MobileTarefasApp extends StatelessWidget {
  const MobileTarefasApp({
    super.key,
    required this.settings,
    required this.router,
    required this.connectivity,
    this.messengerKey,
  });

  final AppSettings settings;
  final GoRouter router;
  final ConnectivityService connectivity;

  /// Por onde o host mostra avisos fora de qualquer tela, como o do
  /// aparelho com root ou jailbreak (capítulo 38).
  final GlobalKey<ScaffoldMessengerState>? messengerKey;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp.router(
        scaffoldMessengerKey: messengerKey,
        onGenerateTitle: (context) =>
            MobileTarefasLocalizations.of(context).appTitle,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: settings.themeMode,
        // Nunca nulo: nulo faria o Flutter usar o idioma do sistema.
        locale: settings.locale ?? AppLanguages.template,
        supportedLocales: AppLanguages.supported,
        localizationsDelegates: appLocalizationsDelegates,
        routerConfig: router,
        builder: (context, child) => ConnectivityBannerHost(
          connectivity: connectivity,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Os delegates do app: o do host, um por módulo com texto e os do
/// Flutter, que traduzem os widgets do Material e do Cupertino. Um módulo
/// novo com telas acrescenta uma linha na lista de baixo, e nada mais no
/// host muda por causa dos textos (capítulo 28, passo 6).
const appLocalizationsDelegates = <LocalizationsDelegate<Object?>>[
  MobileTarefasLocalizations.delegate,
  ...moduleLocalizationsDelegates,
  ...GlobalMaterialLocalizations.delegates,
];

/// Os delegates dos módulos. O teste de idiomas confere que cada um traduz
/// todos os idiomas de [AppLanguages].
const moduleLocalizationsDelegates = <LocalizationsDelegate<Object?>>[
  AuthModuleLocalizations.delegate,
  TasksModuleLocalizations.delegate,
];
