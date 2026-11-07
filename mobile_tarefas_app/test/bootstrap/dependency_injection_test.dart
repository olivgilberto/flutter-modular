import 'package:adapter_analytics_firebase/adapter_analytics_firebase.dart';
import 'package:adapter_connectivity_connectivity_plus/adapter_connectivity_connectivity_plus.dart';
import 'package:adapter_db_sqlcipher/adapter_db_sqlcipher.dart';
import 'package:adapter_http_http/adapter_http_http.dart';
import 'package:adapter_logging_crashlytics/adapter_logging_crashlytics.dart';
import 'package:adapter_sync_workmanager/adapter_sync_workmanager.dart';
import 'package:auth_module/auth_module.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_tarefas_app/bootstrap/app_config.dart';
import 'package:mobile_tarefas_app/bootstrap/dependency_injection.dart';

/// Um cleaner de um módulo que ainda não existe.
final class _Cleaner implements ClearableOnLogout {
  var cleared = 0;

  @override
  Future<void> clearLocalData() async => cleared++;
}

/// A fila de um módulo que ainda não existe.
final class _Outbox implements SyncableOutbox {
  @override
  String get name => 'outro';

  @override
  Future<int> pendingCount() async => 0;

  @override
  Future<bool> sync() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Cada teste monta o composition root num escopo próprio, desfeito no fim:
  // nunca reset() nem allowReassignment.
  setUp(() {
    getIt.pushNewScope(scopeName: 'test');
    configureDependencies(
      const AppConfig(
        flavor: Flavor.dev,
        apiBaseUrl: 'https://api.dev.mobiletarefas.example',
      ),
    );
  });
  tearDown(() => getIt.popScopesTill('test'));

  test('cada porta do core está ligada ao seu adaptador, pelo tipo', () {
    expect(getIt<AppLogger>(), isA<CrashlyticsAppLogger>());
    expect(getIt<AppAnalytics>(), isA<FirebaseAppAnalytics>());
    // O HttpApiClient, dentro do decorador do core (capítulos 35 e 41).
    expect(getIt<ApiClient>(), isA<ConnectivityReportingApiClient>());
    expect(getIt<LocalDatabaseFactory>(), isA<SqlcipherLocalDatabaseFactory>());
    expect(
      getIt<NetworkInterfaceMonitor>(),
      isA<ConnectivityPlusNetworkInterfaceMonitor>(),
    );
    expect(getIt<ReachabilityProbe>(), isA<HttpReachabilityProbe>());
    expect(getIt<SyncScheduler>(), isA<WorkmanagerSyncScheduler>());
    // O SharedPreferencesAsync exige o plugin nativo, que não existe nos
    // testes; o adaptador tem os próprios testes (capítulo 18).
    expect(getIt.isRegistered<AppPreferences>(), isTrue);
  });

  test('os códigos sem tecnologia do core se montam com o que foi '
      'registrado', () {
    expect(getIt<SyncOrchestrator>(), isNotNull);
    expect(getIt<ConnectivityService>(), isA<DefaultConnectivityService>());
    expect(getIt<LogoutCleanerRegistry>(), isA<DefaultLogoutCleanerRegistry>());
    expect(getIt<OutboxRegistry>(), isA<DefaultOutboxRegistry>());
  });

  test('o auth_module completa o core com o TokenProvider e publica o '
      'estado da sessão', () {
    expect(getIt.isRegistered<TokenProvider>(), isTrue);
    expect(getIt<SessionBloc>().state, isA<SessionUnknown>());
  });

  test('o escopo da sessão abre uma vez e, ao fechar, esvazia os '
      'registries', () async {
    final cleaner = _Cleaner();

    openSessionScope();
    openSessionScope();
    expect(getIt.hasScope(sessionScope), isTrue);
    getIt<LogoutCleanerRegistry>().register(cleaner);

    await closeSessionScope();
    expect(getIt.hasScope(sessionScope), isFalse);
    await getIt<LogoutCleanerRegistry>().clearAll();
    expect(cleaner.cleared, 0);

    // Fechar sem escopo aberto, como no boot sem sessão, não é erro.
    await closeSessionScope();
  });

  test('renovar o escopo da sessão esvazia os registries e deixa um escopo '
      'novo aberto, à espera da próxima sessão', () async {
    openSessionScope();
    final tasksOutbox = getIt<OutboxRegistry>().outboxes.single;
    getIt<OutboxRegistry>().register(_Outbox());

    await renewSessionScope();

    // Só a fila que o módulo de tarefas inscreveu no escopo novo, e não a
    // da sessão anterior. Os cleaners não são chamados aqui: o do módulo
    // abriria o banco SQLCipher, que só existe no aparelho.
    expect(getIt.hasScope(sessionScope), isTrue);
    final outboxes = getIt<OutboxRegistry>().outboxes;
    expect(outboxes, hasLength(1));
    expect(outboxes.single, isNot(same(tasksOutbox)));
    expect(outboxes.single.name, 'tasks');

    await closeSessionScope();
  });
}
