import 'package:adapter_http_http/adapter_http_http.dart';
import 'package:core/core.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  late FakeLogger logger;

  setUp(() => logger = FakeLogger());

  (HttpApiClient, FakeServer) clientWith(
    List<Responder> responders, {
    TokenProvider? tokenProvider,
  }) {
    final server = FakeServer(responders);
    final client = HttpApiClient(
      baseUrl: 'https://api.exemplo.com',
      tokenProvider: () => tokenProvider,
      logger: logger,
      retryBaseDelay: Duration.zero,
      client: server.client,
    );
    return (client, server);
  }

  test('devolve o corpo já decodificado', () async {
    final (client, _) = clientWith([(_) => json(200, '{"id": 1}')]);

    expect(await client.get('/tasks'), {'id': 1});
  });

  test('4xx vira rejected, com status e corpo, sem nova tentativa', () async {
    final (client, server) = clientWith([
      (_) => json(422, '{"code": "title_required"}'),
    ]);

    await expectLater(
      client.post('/tasks', body: {'title': ''}),
      throwsA(
        isA<ApiError>()
            .having((e) => e.kind, 'kind', ApiErrorKind.rejected)
            .having((e) => e.statusCode, 'statusCode', 422)
            .having((e) => e.body, 'body', {'code': 'title_required'}),
      ),
    );
    expect(server.requests, hasLength(1));
  });

  test('5xx é repetido e pode dar certo na tentativa seguinte', () async {
    final (client, server) = clientWith([
      (_) => json(503, '{}'),
      (_) => json(200, '{"ok": true}'),
    ]);

    expect(await client.get('/tasks'), {'ok': true});
    expect(server.requests, hasLength(2));
  });

  test('5xx persistente vira server depois de três tentativas', () async {
    final (client, server) = clientWith([(_) => json(500, '{}')]);

    await expectLater(
      client.get('/tasks'),
      throwsA(
        isA<ApiError>().having((e) => e.kind, 'kind', ApiErrorKind.server),
      ),
    );
    expect(server.requests, hasLength(3));
  });

  test('sem rede vira unreachable depois de três tentativas', () async {
    final (client, server) = clientWith([offline]);

    await expectLater(
      client.get('/tasks'),
      throwsA(
        isA<ApiError>()
            .having((e) => e.kind, 'kind', ApiErrorKind.unreachable)
            .having((e) => e.isTransient, 'isTransient', isTrue),
      ),
    );
    expect(server.requests, hasLength(3));
  });

  test('corpo que não é JSON vira invalidResponse, sem o corpo', () async {
    final (client, _) = clientWith([(_) => json(200, '<html>')]);

    await expectLater(
      client.get('/tasks'),
      throwsA(
        isA<ApiError>()
            .having((e) => e.kind, 'kind', ApiErrorKind.invalidResponse)
            .having((e) => e.body, 'body', isNull),
      ),
    );
  });

  test('a chave de idempotência vai em todas as tentativas', () async {
    final (client, server) = clientWith([
      (_) => json(503, '{}'),
      (_) => json(201, '{}'),
    ]);

    await client.post('/tasks', body: {}, idempotencyKey: 'op-42');

    expect(server.requests.map((r) => r.headers['Idempotency-Key']), [
      'op-42',
      'op-42',
    ]);
  });

  test('envia o token só quando há TokenProvider', () async {
    final (anonymous, anonymousServer) = clientWith([(_) => json(200, '{}')]);
    final (signedIn, signedInServer) = clientWith([
      (_) => json(200, '{}'),
    ], tokenProvider: FakeTokenProvider('segredo'));

    await anonymous.get('/tasks');
    await signedIn.get('/tasks');

    expect(anonymousServer.requests.single.headers['Authorization'], isNull);
    expect(
      signedInServer.requests.single.headers['Authorization'],
      'Bearer segredo',
    );
  });

  test('o log tem método, caminho e status, nunca token nem corpo', () async {
    final (client, _) = clientWith([
      (_) => json(200, '{"email": "ana@exemplo.com"}'),
    ], tokenProvider: FakeTokenProvider('segredo'));

    await client.get('/tasks', query: {'q': 'ana'});

    final line = logger.messages.single;
    expect(line, startsWith('GET /tasks → 200'));
    expect(line, isNot(contains('segredo')));
    expect(line, isNot(contains('ana')));
  });
}
