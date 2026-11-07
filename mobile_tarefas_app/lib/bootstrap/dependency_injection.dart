import 'package:adapter_analytics_firebase/adapter_analytics_firebase.dart';
import 'package:adapter_connectivity_connectivity_plus/adapter_connectivity_connectivity_plus.dart';
import 'package:adapter_db_sqlcipher/adapter_db_sqlcipher.dart';
import 'package:adapter_http_http/adapter_http_http.dart';
import 'package:adapter_logging_crashlytics/adapter_logging_crashlytics.dart';
import 'package:adapter_prefs_shared_preferences/adapter_prefs_shared_preferences.dart';
import 'package:adapter_sync_workmanager/adapter_sync_workmanager.dart';
import 'package:auth_module/auth_module.dart';
import 'package:core/core.dart';
import 'package:get_it/get_it.dart';
import 'package:tasks_module/tasks_module.dart';

import 'app_config.dart';
import 'background_sync.dart';

final getIt = GetIt.instance;

const sessionScope = 'session';

/// Caminho leve e sem autenticação que a sonda de alcançabilidade consulta
/// (capítulo 33). Qualquer resposta HTTP, até um 404, conta como alcançável.
const _healthCheckPath = '/v1/health';

/// O escopo base, que vive enquanto o app vive. Ordem: as portas do core
/// ligadas aos adaptadores e aos códigos sem tecnologia do core; depois, o
/// módulo de autenticação, que completa o core com o TokenProvider e
/// precisa existir antes da sessão, porque é ele que mostra o login. Os
/// valores de cada ambiente vêm do [AppConfig]; uma troca de adaptador por
/// ambiente seria um único `switch (config.flavor)` aqui (capítulo 10), e o
/// projeto não tem nenhuma.
void configureDependencies(AppConfig config) {
  _registerCoreAdapters(getIt, config);
  registerAuthModuleDependencies(getIt);
}

/// O escopo da sessão, onde os módulos de feature se registram, para que
/// nada deles sobreviva à sessão seguinte; o de tarefas desde o capítulo 30.
/// Desde o capítulo 32, ele acompanha os dados do aparelho, e não o login:
/// abre no boot, antes de a sessão guardada ser lida, e é renovado a cada
/// fim de sessão. Dados de uma sessão expirada podem estar no aparelho antes
/// de se saber quem vai entrar, e só os módulos registrados aqui sabem
/// contá-los e apagá-los. O segundo plano o abre só com sessão guardada.
void openSessionScope() {
  if (getIt.hasScope(sessionScope)) return;
  getIt.pushNewScope(
    scopeName: sessionScope,
    init: (scope) {
      registerTasksModuleDependencies(scope);
    },
    dispose: () {
      getIt<LogoutCleanerRegistry>().unregisterAll();
      getIt<OutboxRegistry>().unregisterAll();
    },
  );
}

/// Sem escopo aberto, não há o que fechar.
Future<void> closeSessionScope() async {
  if (!getIt.hasScope(sessionScope)) return;
  await getIt.popScopesTill(sessionScope);
}

/// O fim de uma sessão, depois da limpeza (capítulo 32): o escopo fecha,
/// levando as instâncias da sessão que acabou e esvaziando os registries, e
/// abre de novo, vazio, à espera da próxima. Uma limpeza que falhou deixa o
/// dono dos dados gravado, e o próximo login de outra pessoa ainda encontra
/// os módulos para apagar o que sobrou.
Future<void> renewSessionScope() async {
  await closeSessionScope();
  openSessionScope();
}

/// O único lugar que sabe qual adaptador atende cada porta do core. Sempre
/// pelo tipo da porta e com uma função explícita, nunca um tear-off: a lista
/// de dependências fica à vista e o build quebra quando ela muda.
void _registerCoreAdapters(GetIt getIt, AppConfig config) {
  getIt
    ..registerLazySingleton<AppLogger>(() => CrashlyticsAppLogger())
    ..registerLazySingleton<AppAnalytics>(
      () => FirebaseAppAnalytics(logger: getIt<AppLogger>()),
    )
    // O pacote http por dentro (capítulo 41); por fora, o core conta ao
    // ConnectivityService o que cada requisição descobre sobre o backend
    // (capítulo 35).
    ..registerLazySingleton<ApiClient>(
      () => ConnectivityReportingApiClient(
        inner: HttpApiClient(
          baseUrl: config.apiBaseUrl,
          // Nulo até um módulo de autenticação registrar um TokenProvider.
          tokenProvider: () => getIt.isRegistered<TokenProvider>()
              ? getIt<TokenProvider>()
              : null,
          logger: getIt<AppLogger>(),
        ),
        connectivityService: getIt<ConnectivityService>(),
      ),
    )
    ..registerLazySingleton<LocalDatabaseFactory>(
      () => SqlcipherLocalDatabaseFactory(),
    )
    ..registerLazySingleton<AppPreferences>(
      () => SharedPreferencesAppPreferences(),
    )
    ..registerLazySingleton<NetworkInterfaceMonitor>(
      () => ConnectivityPlusNetworkInterfaceMonitor(),
    )
    ..registerLazySingleton<ReachabilityProbe>(
      () => HttpReachabilityProbe(
        baseUrl: config.apiBaseUrl,
        path: _healthCheckPath,
      ),
    )
    ..registerLazySingleton<ConnectivityService>(
      () => DefaultConnectivityService(
        networkInterfaceMonitor: getIt<NetworkInterfaceMonitor>(),
        reachabilityProbe: getIt<ReachabilityProbe>(),
      ),
      dispose: (service) => service.dispose(),
    )
    ..registerLazySingleton<LogoutCleanerRegistry>(
      () => DefaultLogoutCleanerRegistry(),
    )
    ..registerLazySingleton<OutboxRegistry>(() => DefaultOutboxRegistry())
    ..registerLazySingleton<OutboxSyncWorker>(
      () => OutboxSyncWorker(
        registry: getIt<OutboxRegistry>(),
        logger: getIt<AppLogger>(),
      ),
    )
    // O ponto de entrada em segundo plano é do host; o adaptador o liga ao
    // workmanager (capítulos 10 e 32).
    ..registerLazySingleton<SyncScheduler>(
      () => WorkmanagerSyncScheduler(callbackDispatcher: outboxSyncDispatcher),
    )
    ..registerLazySingleton<SyncOrchestrator>(
      () => SyncOrchestrator(
        connectivityService: getIt<ConnectivityService>(),
        outboxSyncWorker: getIt<OutboxSyncWorker>(),
      ),
      dispose: (orchestrator) => orchestrator.dispose(),
    );
}
