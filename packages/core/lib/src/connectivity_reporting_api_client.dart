import 'dart:async';

import 'api_client.dart';
import 'connectivity.dart';

/// Um [ApiClient] que conta ao [ConnectivityService] o que as requisições
/// descobrem sobre o backend (capítulo 35). O serviço só verifica ao começar
/// e quando a interface de rede muda; um backend que cai, ou volta, com a
/// interface ligada passaria despercebido, sem aviso na tela e sem a
/// transição para online que faz a fila subir.
///
/// - Uma requisição que não chegou ao servidor, com o estado `online`, pede
///   uma verificação: se o backend caiu, o estado vira `noInternet`, o aviso
///   aparece, e as novas verificações com espera crescente começam.
/// - Uma resposta qualquer, com o estado `noInternet`, também pede: o
///   backend voltou, e a transição para `online` faz o [SyncOrchestrator]
///   enviar as filas.
///
/// Com o estado `unknown`, nada é pedido: o serviço ainda não começou, como
/// no segundo plano, onde ninguém mostra aviso nem orquestra o envio.
/// Nenhuma requisição espera a verificação, e nenhum erro muda.
final class ConnectivityReportingApiClient implements ApiClient {
  ConnectivityReportingApiClient({
    required ApiClient inner,
    required ConnectivityService connectivityService,
  }) : _inner = inner,
       _connectivity = connectivityService;

  final ApiClient _inner;
  final ConnectivityService _connectivity;

  @override
  Future<Object?> get(String path, {Map<String, String>? query}) =>
      _report(() => _inner.get(path, query: query));

  @override
  Future<Object?> post(
    String path, {
    Object? body,
    String? idempotencyKey,
    bool authenticated = true,
  }) => _report(
    () => _inner.post(
      path,
      body: body,
      idempotencyKey: idempotencyKey,
      authenticated: authenticated,
    ),
  );

  @override
  Future<Object?> put(String path, {Object? body, String? idempotencyKey}) =>
      _report(
        () => _inner.put(path, body: body, idempotencyKey: idempotencyKey),
      );

  @override
  Future<Object?> patch(String path, {Object? body, String? idempotencyKey}) =>
      _report(
        () => _inner.patch(path, body: body, idempotencyKey: idempotencyKey),
      );

  @override
  Future<Object?> delete(String path, {String? idempotencyKey}) =>
      _report(() => _inner.delete(path, idempotencyKey: idempotencyKey));

  Future<Object?> _report(Future<Object?> Function() request) async {
    try {
      final response = await request();
      _recheckIf(ConnectivityStatus.noInternet);
      return response;
    } on ApiError catch (error) {
      if (error.kind == ApiErrorKind.unreachable) {
        _recheckIf(ConnectivityStatus.online);
      } else {
        // O servidor respondeu, mesmo recusando: ele está no ar.
        _recheckIf(ConnectivityStatus.noInternet);
      }
      rethrow;
    }
  }

  void _recheckIf(ConnectivityStatus status) {
    if (_connectivity.status == status) unawaited(_connectivity.check());
  }
}
