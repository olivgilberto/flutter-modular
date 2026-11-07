import 'dart:async';

import 'package:core/core.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get_it/get_it.dart';

import '../settings/app_settings.dart';
import 'dependency_injection.dart' show getIt;
import 'error_handling.dart';

/// O tempo máximo de cada passo assíncrono. O boot nunca espera a rede nem
/// um plugin sem limite: passado o tempo, segue pelo caminho alternativo.
const bootStepTimeout = Duration(seconds: 5);

/// Os passos 1 a 8 da sequência de boot (seção 25.1). O 9 é o `runApp`, no
/// `mainCommon`; o 10, o redirect do roteador. As funções são parâmetros
/// para que os testes troquem o Firebase, os handlers, o composition root e
/// o agendamento; o composition root não tem padrão porque depende do
/// flavor (capítulo 26).
Future<AppSettings> boot({
  Future<void> Function() initializeFirebase = initializeFirebaseApp,
  void Function() installErrorHandlers = installGlobalErrorHandlers,
  required void Function() configure,
  Future<void> Function() scheduleSync = _schedulePeriodicSync,
  Duration timeout = bootStepTimeout,
}) async {
  // 1. Firebase, com as opções do flavor (capítulo 38). Um flavor ainda sem
  //    projeto no Firebase falha aqui; o app segue, e os adaptadores do
  //    Firebase escrevem no console.
  Object? firebaseFailure;
  try {
    await initializeFirebase().timeout(timeout);
  } on Exception catch (error) {
    firebaseFailure = error;
  }

  // 2. App Tracking Transparency: o pedido só aparece com o app ativo, e
  //    por isso roda depois do runApp (capítulo 38, no mainCommon).

  // 3. Handlers globais de erro.
  installErrorHandlers();

  // 4. Injeção de dependências e espera pelos serviços assíncronos.
  configure();
  final logger = getIt<AppLogger>();
  try {
    await getIt.allReady(timeout: timeout);
  } on WaitingTimeOutException catch (error) {
    logger.log('boot: serviços não prontos: ${error.notReadyYet}');
  }
  if (firebaseFailure != null) {
    logger.log('boot: Firebase indisponível (${firebaseFailure.runtimeType})');
  }

  // 4, fim. A sincronização com o app fechado (capítulo 32). A do app
  //    aberto, o SyncOrchestrator.start(), entra com a conectividade no
  //    capítulo 33. Uma falha aqui não impede o app de abrir: a fila sobe
  //    com o app aberto, e o próximo boot agenda de novo.
  try {
    await scheduleSync().timeout(timeout);
  } on Exception catch (error, stackTrace) {
    logger.error('boot sync schedule', error, stackTrace);
  }

  // 5. Preferências locais (tema e idioma), com tempo limite e padrões. A
  //    conectividade fecha o passo, no mainCommon, depois de o escopo da
  //    sessão abrir (startConnectivity, capítulo 33).
  final settings = await AppSettings.load(
    preferences: getIt<AppPreferences>(),
    logger: logger,
    timeout: timeout,
  );

  // 6 a 8. Remote Config, atualização obrigatória e novo aceite dos termos:
  //    o mobile_tarefas não tem nenhum dos três (seção 25.1).

  return settings;
}

/// Também o passo 1 do segundo plano (capítulo 32).
///
/// Cópia pública do livro: sem [options], nenhum flavor tem projeto do
/// Firebase (veja `firebase_options.dart`), e o Firebase não é chamado; no
/// iOS, procurar uma configuração nativa que não existe encerraria o app. Os
/// adaptadores do Firebase escrevem no console. No livro, sem [options], o
/// Firebase procura a configuração nativa do flavor.
Future<void> initializeFirebaseApp([FirebaseOptions? options]) async {
  if (options == null) return;
  await Firebase.initializeApp(options: options);
}

Future<void> _schedulePeriodicSync() =>
    getIt<SyncScheduler>().schedulePeriodicSync();

/// O fim do passo 5 (capítulo 33). O orquestrador sincroniza a cada
/// transição para online, e na hora se o estado já for online quando ele
/// começa. A verificação nunca é aguardada, porque vai à rede: o app abre
/// com o estado `unknown`, sem aviso. O mainCommon chama esta função depois de o
/// escopo da sessão abrir, para que a primeira sincronização já encontre as
/// filas dos módulos.
void startConnectivity({
  required ConnectivityService connectivity,
  required SyncOrchestrator orchestrator,
}) {
  orchestrator.start();
  unawaited(connectivity.start());
}
