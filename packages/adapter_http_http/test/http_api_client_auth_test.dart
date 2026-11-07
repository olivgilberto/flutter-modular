import 'package:adapter_http_http/adapter_http_http.dart';
import 'package:core/core.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  (HttpApiClient, FakeServer) clientWith(
    List<Responder> responders,
    TokenProvider? tokenProvider,
  ) {
    final server = FakeServer(responders);
    final client = HttpApiClient(
      baseUrl: 'https://api.exemplo.com',
      tokenProvider: () => tokenProvider,
      logger: FakeLogger(),
      retryBaseDelay: Duration.zero,
      client: server.client,
    );
    return (client, server);
  }

  Iterable<Object?> authorizations(FakeServer server) =>
      server.requests.map((r) => r.headers['Authorization']);

  Matcher apiError(ApiErrorKind kind, {int? statusCode}) => throwsA(
    isA<ApiError>()
        .having((e) => e.kind, 'kind', kind)
        .having((e) => e.statusCode, 'statusCode', statusCode),
  );

  test('401 com token: renova uma vez e repete com o token novo', () async {
    final provider = FakeTokenProvider('vencido', refreshed: 'novo');
    final (client, server) = clientWith([
      (_) => json(401, '{}'),
      (_) => json(200, '{"ok": true}'),
    ], provider);

    expect(await client.get('/tasks'), {'ok': true});
    expect(provider.refreshCalls, 1);
    expect(authorizations(server), ['Bearer vencido', 'Bearer novo']);
  });

  test('um segundo 401 depois da renovação não renova de novo', () async {
    final provider = FakeTokenProvider('vencido', refreshed: 'novo');
    final (client, server) = clientWith([(_) => json(401, '{}')], provider);

    await expectLater(
      client.get('/tasks'),
      apiError(ApiErrorKind.rejected, statusCode: 401),
    );
    expect(provider.refreshCalls, 1);
    expect(server.requests, hasLength(2));
  });

  test('renovação recusada: o 401 sobe e a requisição não se repete', () async {
    final provider = FakeTokenProvider('vencido');
    final (client, server) = clientWith([(_) => json(401, '{}')], provider);

    await expectLater(
      client.get('/tasks'),
      apiError(ApiErrorKind.rejected, statusCode: 401),
    );
    expect(provider.refreshCalls, 1);
    expect(server.requests, hasLength(1));
  });

  test('renovação sem rede: sobe o erro transitório, não o 401', () async {
    final provider = FakeTokenProvider(
      'vencido',
      refreshError: const ApiError(ApiErrorKind.unreachable),
    );
    final (client, server) = clientWith([(_) => json(401, '{}')], provider);

    await expectLater(client.get('/tasks'), apiError(ApiErrorKind.unreachable));
    expect(server.requests, hasLength(1));
  });

  test('um 401 sem token, como o do login, não pede renovação', () async {
    final provider = FakeTokenProvider(null, refreshed: 'novo');
    final (client, _) = clientWith([(_) => json(401, '{}')], provider);

    await expectLater(
      client.post('/v1/auth/sign-in', body: {}),
      apiError(ApiErrorKind.rejected, statusCode: 401),
    );
    expect(provider.refreshCalls, 0);
  });

  test('uma requisição sem autenticação não leva o token nem renova', () async {
    final provider = FakeTokenProvider('vencido', refreshed: 'novo');
    final (client, server) = clientWith([(_) => json(401, '{}')], provider);

    await expectLater(
      client.post('/v1/auth/refresh', body: {}, authenticated: false),
      apiError(ApiErrorKind.rejected, statusCode: 401),
    );
    expect(authorizations(server), [null]);
    expect(provider.refreshCalls, 0);
  });
}
