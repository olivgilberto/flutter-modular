import 'package:core/core.dart';
import 'package:test/test.dart';

import 'fakes.dart';

/// O estado controlado pelo teste, com as verificações contadas.
final class _Connectivity implements ConnectivityService {
  _Connectivity(this.status);

  @override
  ConnectivityStatus status;
  var checks = 0;

  @override
  Stream<ConnectivityStatus> get statusChanges => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<ConnectivityStatus> check() async {
    checks++;
    return status;
  }

  @override
  Future<void> dispose() async {}
}

/// Responde ou lança o que o teste mandar, em qualquer método.
final class _Api implements ApiClient {
  Object? answer;
  Object? error;

  Future<Object?> _reply() async {
    if (error case final error?) throw error;
    return answer;
  }

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

void main() {
  late _Api inner;

  setUp(() => inner = _Api());

  ConnectivityReportingApiClient over(ConnectivityService connectivity) =>
      ConnectivityReportingApiClient(
        inner: inner,
        connectivityService: connectivity,
      );

  const unreachable = ApiError(ApiErrorKind.unreachable);
  const rejected = ApiError(ApiErrorKind.rejected, statusCode: 409);

  test('online, a requisição que não chegou pede uma verificação, e o erro '
      'sobe como estava', () async {
    final connectivity = _Connectivity(ConnectivityStatus.online);
    final api = over(connectivity);
    inner.error = unreachable;

    for (final call in <Future<Object?> Function()>[
      () => api.get('/a'),
      () => api.post('/a'),
      () => api.put('/a'),
      () => api.patch('/a'),
      () => api.delete('/a'),
    ]) {
      await expectLater(call(), throwsA(same(unreachable)));
    }

    expect(connectivity.checks, 5);
  });

  test('sem conexão com o backend, qualquer resposta pede uma verificação; '
      'a falha de transporte, não', () async {
    final connectivity = _Connectivity(ConnectivityStatus.noInternet);
    final api = over(connectivity);

    inner.answer = {'ok': true};
    expect(await api.get('/a'), {'ok': true});
    inner.error = rejected;
    await expectLater(api.patch('/a'), throwsA(same(rejected)));
    expect(connectivity.checks, 2);

    inner.error = unreachable;
    await expectLater(api.get('/a'), throwsA(same(unreachable)));
    expect(connectivity.checks, 2);
  });

  test(
    'online e respondendo, ou sem estado ainda, nada é verificado',
    () async {
      final online = _Connectivity(ConnectivityStatus.online);
      inner.answer = 'ok';
      await over(online).get('/a');
      inner.error = rejected;
      await expectLater(over(online).get('/a'), throwsA(same(rejected)));
      expect(online.checks, 0);

      // Antes do start(), como no segundo plano.
      final unknown = _Connectivity(ConnectivityStatus.unknown);
      inner.error = unreachable;
      await expectLater(over(unknown).get('/a'), throwsA(same(unreachable)));
      expect(unknown.checks, 0);
    },
  );

  test('com o serviço de verdade: o backend que cai vira noInternet, e o '
      'que volta vira online, sem mudança de interface', () async {
    final probe = FakeProbe();
    final connectivity = DefaultConnectivityService(
      networkInterfaceMonitor: FakeMonitor(),
      reachabilityProbe: probe,
      // Longo: só as requisições disparam verificações neste teste.
      minRecheckDelay: const Duration(hours: 1),
    );
    addTearDown(connectivity.dispose);
    final seen = <ConnectivityStatus>[];
    connectivity.statusChanges.listen(seen.add);
    await connectivity.start();
    final api = over(connectivity);

    probe.reachable = false;
    inner.error = unreachable;
    await expectLater(api.put('/a'), throwsA(same(unreachable)));
    await pumpEventQueue();
    expect(connectivity.status, ConnectivityStatus.noInternet);

    probe.reachable = true;
    inner
      ..error = null
      ..answer = {'version': 1};
    await api.put('/a');
    await pumpEventQueue();

    expect(seen, [
      ConnectivityStatus.online,
      ConnectivityStatus.noInternet,
      ConnectivityStatus.online,
    ]);
  });
}
