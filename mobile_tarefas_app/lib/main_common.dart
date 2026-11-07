import 'package:auth_module/auth_module.dart';
import 'package:bloc/bloc.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'bootstrap/app_config.dart';
import 'bootstrap/app_router.dart';
import 'bootstrap/boot.dart';
import 'bootstrap/dependency_injection.dart';
import 'bootstrap/error_handling.dart';
import 'bootstrap/firebase_options.dart';
import 'observability/app_bloc_observer.dart';
import 'security/device_integrity.dart';
import 'security/tracking_authorization.dart';
import 'session/session_gate.dart';

/// O ponto de entrada comum aos três flavors (capítulo 26). Cada
/// `main_[flavor].dart` só diz qual é o seu.
///
/// Os três parâmetros nomeados são dos testes de integração (capítulo 39),
/// que montam o app inteiro no aparelho e desligam só o que não pode rodar
/// num teste: o Firebase, para que eventos e erros de teste não se misturem
/// aos de uso no console; os handlers globais, porque num teste o handler
/// de erros é o do próprio framework, que transforma cada erro numa falha;
/// e o pedido de rastreamento, um alerta do sistema que o teste não
/// alcança. Em produção, os três ficam ligados.
Future<void> mainCommon(
  Flavor flavor, {
  bool withFirebase = true,
  bool withErrorHandlers = true,
  bool withTrackingRequest = true,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment(flavor);
  final settings = await boot(
    initializeFirebase: withFirebase
        ? () => initializeFirebaseApp(firebaseOptionsFor(flavor))
        : () async {},
    installErrorHandlers: withErrorHandlers
        ? installGlobalErrorHandlers
        : () {},
    configure: () => configureDependencies(config),
  );
  final logger = getIt<AppLogger>();
  // O erro que escapa de um Bloc chega ao registro (capítulo 38).
  Bloc.observer = AppBlocObserver(logger);

  // O fim do passo 5: a sessão guardada no aparelho (capítulo 28). O
  // escopo da sessão abre antes da leitura: dados de uma sessão que
  // expirou antes de o app fechar podem estar no aparelho, e só os módulos
  // sabem contá-los e apagá-los (capítulo 32).
  openSessionScope();
  final sessionBloc = getIt<SessionBloc>();
  final session = SessionGate(
    initial: sessionBloc.state,
    changes: sessionBloc.stream,
    onSignedIn: openSessionScope,
    onSignedOut: renewSessionScope,
  );
  sessionBloc.add(const SessionRestoreRequested());
  await session.waitUntilKnown(timeout: bootStepTimeout, logger: logger);
  // E a conectividade, com o escopo já aberto (capítulo 33).
  startConnectivity(
    connectivity: getIt<ConnectivityService>(),
    orchestrator: getIt<SyncOrchestrator>(),
  );

  // 9. runApp. O 10, o redirect, roda a cada navegação.
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  runApp(
    MobileTarefasApp(
      settings: settings,
      router: createAppRouter(
        settings,
        session,
        analytics: getIt<AppAnalytics>(),
      ),
      connectivity: getIt<ConnectivityService>(),
      messengerKey: messengerKey,
    ),
  );

  // Com a primeira tela à vista e o app ativo (capítulo 38): o pedido de
  // rastreamento, que a Apple só mostra nessa hora, e o aviso de root ou
  // jailbreak, que precisa de uma tela onde aparecer.
  if (withTrackingRequest) {
    await appActive(WidgetsBinding.instance);
    await requestTrackingAuthorization(logger: logger);
  }
  if (await deviceCompromised(logger: logger)) {
    final messenger = messengerKey.currentState;
    if (messenger != null) showDeviceIntegrityNotice(messenger);
  }
}
