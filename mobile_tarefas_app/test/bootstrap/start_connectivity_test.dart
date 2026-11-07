import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_tarefas_app/bootstrap/boot.dart';

import '../support/fakes.dart';

/// A interface de rede, controlada pelo teste.
final class _Monitor implements NetworkInterfaceMonitor {
  var hasInterface = true;
  final changes = StreamController<bool>.broadcast();

  @override
  Future<bool> hasNetworkInterface() async => hasInterface;

  @override
  Stream<bool> get networkInterfaceChanges => changes.stream;
}

/// O backend, que o teste pode tirar do ar.
final class _Probe implements ReachabilityProbe {
  var up = true;

  @override
  Future<bool> isBackendReachable() async => up;
}

/// As requisições do app, que falham enquanto o backend está fora do ar.
final class _Api implements ApiClient {
  _Api(this._probe);

  final _Probe _probe;

  Future<Object?> _reply() async => _probe.up
      ? {'version': 1}
      : throw const ApiError(ApiErrorKind.unreachable);

  @override
  Future<Object?> get(String path, {Map<String, String>? query}) => _reply();

  @override
  Future<Object?> post(
    String path, {
    Object? body,
    String? idempotencyKey,
    bool authenticated = true,
  }) => _reply();

  @override
  Future<Object?> put(String path, {Object? body, String? idempotencyKey}) =>
      _reply();

  @override
  Future<Object?> patch(String path, {Object? body, String? idempotencyKey}) =>
      _reply();

  @override
  Future<Object?> delete(String path, {String? idempotencyKey}) => _reply();
}

/// Uma fila que conta os envios.
final class _Outbox implements SyncableOutbox {
  var syncs = 0;

  @override
  String get name => 'tasks';

  @override
  Future<int> pendingCount() async => 0;

  @override
  Future<bool> sync() async {
    syncs++;
    return false;
  }
}

void main() {
  late _Monitor monitor;
  late _Probe probe;
  late _Outbox outbox;
  late DefaultConnectivityService connectivity;
  late SyncOrchestrator orchestrator;

  setUp(() {
    monitor = _Monitor();
    probe = _Probe();
    outbox = _Outbox();
    final registry = DefaultOutboxRegistry()..register(outbox);
    connectivity = DefaultConnectivityService(
      networkInterfaceMonitor: monitor,
      reachabilityProbe: probe,
    );
    orchestrator = SyncOrchestrator(
      connectivityService: connectivity,
      outboxSyncWorker: OutboxSyncWorker(
        registry: registry,
        logger: FakeLogger(),
      ),
      debounce: Duration.zero,
    );
  });
  tearDown(() async {
    await orchestrator.dispose();
    await connectivity.dispose();
  });

  /// O tempo do intervalo do orquestrador e do envio.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test('no boot, a primeira verificação online envia as filas', () async {
    startConnectivity(connectivity: connectivity, orchestrator: orchestrator);
    await settle();

    expect(connectivity.status, ConnectivityStatus.online);
    expect(outbox.syncs, 1);
  });

  test('a rede que cai e volta envia de novo; sem rede, nada é '
      'enviado', () async {
    startConnectivity(connectivity: connectivity, orchestrator: orchestrator);
    await settle();

    monitor.hasInterface = false;
    monitor.changes.add(false);
    await settle();
    expect(connectivity.status, ConnectivityStatus.offline);
    expect(outbox.syncs, 1);

    monitor.hasInterface = true;
    monitor.changes.add(true);
    await settle();
    expect(connectivity.status, ConnectivityStatus.online);
    expect(outbox.syncs, 2);
  });

  test('o backend que cai com a interface ligada mostra o aviso, e o que '
      'volta envia a fila sem esperar outra escrita (capítulo 35)', () async {
    // As mesmas peças, com a nova verificação em milissegundos, no lugar
    // dos 15 segundos do app.
    final quick = DefaultConnectivityService(
      networkInterfaceMonitor: monitor,
      reachabilityProbe: probe,
      minRecheckDelay: const Duration(milliseconds: 30),
    );
    final quickOrchestrator = SyncOrchestrator(
      connectivityService: quick,
      outboxSyncWorker: OutboxSyncWorker(
        registry: DefaultOutboxRegistry()..register(outbox),
        logger: FakeLogger(),
      ),
      debounce: Duration.zero,
    );
    addTearDown(() async {
      await quickOrchestrator.dispose();
      await quick.dispose();
    });
    final api = ConnectivityReportingApiClient(
      inner: _Api(probe),
      connectivityService: quick,
    );
    startConnectivity(connectivity: quick, orchestrator: quickOrchestrator);
    await settle();
    expect(outbox.syncs, 1);

    // O roteiro no simulador: "parar" no dev_backend, e uma escrita que não
    // chega. A interface continua ligada.
    probe.up = false;
    await expectLater(api.put('/v1/tasks/t-1'), throwsA(isA<ApiError>()));
    await settle();
    expect(quick.status, ConnectivityStatus.noInternet);

    // "voltar", sem nenhuma ação no app: a nova verificação acha o backend,
    // e a transição para online envia a fila.
    probe.up = true;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(quick.status, ConnectivityStatus.online);
    expect(outbox.syncs, 2);
  });
}
