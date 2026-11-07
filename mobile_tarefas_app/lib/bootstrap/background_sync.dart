import 'dart:ui' show DartPluginRegistrant;

import 'package:adapter_sync_workmanager/adapter_sync_workmanager.dart';
import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import 'app_config.dart';
import 'boot.dart' show bootStepTimeout, initializeFirebaseApp;
import 'firebase_options.dart';
import 'dependency_injection.dart';

/// O segundo ponto de entrada do app (capítulo 10). O sistema operacional o
/// chama num isolate próprio, com o `get_it` vazio, quando decide rodar a
/// sincronização periódica que o boot agendou. O adaptador o liga ao
/// workmanager; o host nunca importa o workmanager.
@pragma('vm:entry-point')
void outboxSyncDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  runWorkmanagerSyncTask(() {
    final config = AppConfig.forBackground();
    return syncInBackground(
      // As mesmas opções do Firebase do app aberto (capítulo 38).
      initializeFirebase: () =>
          initializeFirebaseApp(firebaseOptionsFor(config.flavor)),
      configure: () => configureDependencies(config),
    );
  });
}

/// Uma execução em segundo plano. Devolve se a tarefa terminou bem, que é o
/// que o workmanager repassa ao sistema; o worker responde a pergunta
/// oposta, "algo ficou para depois?", e a inversão fica só aqui.
///
/// As mesmas funções de composição do `main`, uma vez por isolate: o
/// sistema pode rodar várias execuções no mesmo isolate. As funções são
/// parâmetros para os testes.
Future<bool> syncInBackground({
  required void Function() configure,
  Future<void> Function() initializeFirebase = initializeFirebaseApp,
  void Function() openSession = openSessionScope,
  Duration timeout = bootStepTimeout,
}) async {
  if (!getIt.isRegistered<OutboxSyncWorker>()) {
    // Sem o Firebase, o registro de falhas escreve no console, como no boot.
    try {
      await initializeFirebase().timeout(timeout);
    } on Exception {
      // O app segue, e o motivo já é registrado pelo boot do app aberto.
    }
    configure();
    try {
      await getIt.allReady(timeout: timeout);
    } on WaitingTimeOutException {
      // Segue com o que ficou pronto; o que faltar falha adiante e é
      // registrado.
    }
  }

  final logger = getIt<AppLogger>();
  try {
    // Sem sessão guardada, inclusive depois de uma expiração, a fila espera
    // o próximo login: não há o que tentar de novo agora.
    if (await getIt<TokenProvider>().currentToken() == null) return true;

    openSession();
    final somethingLeft = await getIt<OutboxSyncWorker>().run();
    return !somethingLeft;
  } on LocalDatabaseError catch (error, stackTrace) {
    logger.error('background sync', error, stackTrace);
    return false;
  }
}
