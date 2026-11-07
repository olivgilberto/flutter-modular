import 'dart:io';

import 'package:adapter_http_http/adapter_http_http.dart';
import 'package:auth_module/adapters/driven/models/auth_model.dart';
import 'package:auth_module/adapters/driven/services/rest_auth_token_service.dart';
import 'package:core/core.dart';
import 'package:dev_backend/dev_backend.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:tasks_module/adapters/driven/services/rest_task_service.dart';
import 'package:tasks_module/adapters/driven/task_api_paths.dart';
import 'package:test/test.dart';

/// O contrato visto pelo app: o backend de desenvolvimento num socket de
/// verdade, e do outro lado o HttpApiClient, os Models e os Services REST
/// dos módulos, os mesmos que o app usa. Se o backend se afastar do que o
/// app lê, este teste quebra antes do simulador.
void main() {
  late HttpServer server;
  late DevBackendState state;
  late _Tokens tokens;
  late HttpApiClient api;

  setUp(() async {
    state = DevBackendState();
    server = await shelf_io.serve(
      devBackendHandler(state),
      InternetAddress.loopbackIPv4,
      0,
    );
    tokens = _Tokens();
    api = HttpApiClient(
      baseUrl: 'http://127.0.0.1:${server.port}',
      tokenProvider: () => tokens,
      logger: _SilentLogger(),
      retryBaseDelay: Duration.zero,
    );
  });

  tearDown(() => server.close(force: true));

  Future<AuthModel> register() async {
    final model = AuthModel.fromJson(
      await api.post(
        '/v1/auth/register',
        body: {
          'name': 'Ana',
          'email': 'ana@exemplo.com',
          'password': 'cavalo-bateria-grampo',
        },
        authenticated: false,
      ),
    );
    tokens.access = model.accessToken;
    return model;
  }

  test('o cadastro chega como o AuthModel lê, e a entidade é válida', () async {
    final model = await register();

    expect(model.toEntity().email.value, 'ana@exemplo.com');
    expect(model.refreshToken, isNotEmpty);
  });

  test('a renovação do auth_module troca os tokens', () async {
    final model = await register();

    final renewed = await RestAuthTokenService(
      apiClient: api,
    ).renew(model.refreshToken);

    expect(renewed.accessToken, isNot(model.accessToken));
    expect(renewed.refreshToken, isNot(model.refreshToken));
  });

  test('o token vencido é renovado pelo interceptor, e a requisição '
      'segue', () async {
    final model = await register();
    var refresh = model.refreshToken;
    // Como o AuthTokenProvider do app: a renovação pelo serviço do
    // auth_module, no mesmo ApiClient, sem autenticação.
    tokens.onRefresh = () async {
      final renewed = await RestAuthTokenService(apiClient: api).renew(refresh);
      refresh = renewed.refreshToken;
      return renewed.accessToken;
    };
    state.expireTokens();

    final page = await api.get(TaskApiPaths.tasks, query: {'status': 'active'});

    expect(page, {'items': isEmpty, 'nextCursor': null});
    expect(tokens.refreshes, 1);
  });

  test('o envio da fila: PUT e PATCH com a versão, o 409 que a fila '
      'reconhece, o 404 do arquivamento', () async {
    await register();
    final path = TaskApiPaths.task('t-1');

    final created = await api.put(
      path,
      body: {
        'title': 'Pagar a luz',
        'status': 'open',
        'createdAt': '2026-10-28T09:00:00.000Z',
        'operationId': 'op-1',
      },
      idempotencyKey: 'op-1',
    );
    expect(created, containsPair('version', 1));
    final updated = await api.patch(
      path,
      body: {
        'title': 'Pagar a luz',
        'status': 'done',
        'baseVersion': 1,
        'operationId': 'op-2',
      },
      idempotencyKey: 'op-2',
    );
    expect(updated, containsPair('version', 2));

    state.tasks['t-1']!.version = 5; // outra pessoa
    await expectLater(
      api.patch(
        path,
        body: {'status': 'open', 'baseVersion': 2, 'operationId': 'op-3'},
        idempotencyKey: 'op-3',
      ),
      throwsA(
        isA<ApiError>().having((e) => e.statusCode, 'statusCode', 409).having(
          (e) => e.body,
          'body',
          {'code': 'version_conflict'},
        ),
      ),
    );

    state.tasks.remove('t-1'); // apagada por outra pessoa
    await expectLater(
      api.patch(
        path,
        body: {'status': 'archived', 'baseVersion': 5, 'operationId': 'op-4'},
        idempotencyKey: 'op-4',
      ),
      throwsA(isA<ApiError>().having((e) => e.statusCode, 'statusCode', 404)),
    );
  });

  test('a leitura do tasks_module segue o cursor e busca uma tarefa, com o '
      '404 como apagada', () async {
    await register();
    for (var i = 1; i <= 5; i++) {
      await api.put(
        TaskApiPaths.task('t-$i'),
        body: {
          'title': 'Tarefa $i',
          'status': 'open',
          'createdAt': '2026-10-28T09:0$i:00.000Z',
          'operationId': 'op-$i',
        },
      );
    }
    final service = RestTaskService(apiClient: api, pageSize: 2);

    final listed = await service.fetchActiveTasks();
    expect(
      [for (final task in listed) task.id],
      ['t-1', 't-2', 't-3', 't-4', 't-5'],
    );
    expect((await service.fetchTask('t-3'))?.title, 'Tarefa 3');
    expect(await service.fetchTask('t-9'), isNull);
  });

  test('a sonda de alcance recebe resposta no HEAD de saúde', () async {
    final probe = HttpReachabilityProbe(
      baseUrl: 'http://127.0.0.1:${server.port}',
      path: '/v1/health',
    );
    expect(await probe.isBackendReachable(), isTrue);
  });
}

/// O TokenProvider do teste: o token atual e um contador de renovações.
final class _Tokens implements TokenProvider {
  String? access;
  Future<String?> Function()? onRefresh;
  var refreshes = 0;

  @override
  Future<String?> currentToken() async => access;

  @override
  Future<String?> refreshToken() async {
    refreshes++;
    return access = await onRefresh?.call();
  }
}

final class _SilentLogger implements AppLogger {
  @override
  void log(String message) {}

  @override
  void error(String reason, Object error, StackTrace stackTrace) {}

  @override
  void fatal(Object error, StackTrace stackTrace) {}

  @override
  void setUserId(String? opaqueId) {}
}
