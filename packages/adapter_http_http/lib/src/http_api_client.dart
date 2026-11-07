import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core/core.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

import 'io_client.dart';

/// [ApiClient] com o pacote http. O que no Dio eram três interceptors aqui
/// são três peças à vista: o token e a renovação diante de um 401 ficam no
/// próprio envio; a nova tentativa é o [RetryClient] do pacote; o log e o
/// tempo limite de cada tentativa ficam num cliente de dentro. Toda falha
/// vira [ApiError] antes de sair desta classe; nunca há cache de respostas.
final class HttpApiClient implements ApiClient {
  HttpApiClient({
    required String baseUrl,
    required TokenProvider? Function() tokenProvider,
    required AppLogger logger,
    Duration retryBaseDelay = const Duration(milliseconds: 500),
    Duration timeout = const Duration(seconds: 20),
    http.Client? client,
    Random? random,
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _tokenProvider = tokenProvider,
       _timeout = timeout,
       _client = RetryClient(
         _AttemptClient(
           client ?? ioClient(connectionTimeout: const Duration(seconds: 10)),
           logger,
           timeout,
         ),
         // Três tentativas no total: o RetryClient conta só as repetições.
         retries: 2,
         // Só falhas transitórias: 5xx e falhas de transporte. Nunca um 4xx.
         when: (response) => response.statusCode >= 500,
         whenError: (error, _) => _isTransport(error),
         delay: _backoff(retryBaseDelay, random ?? Random()),
       );

  final String _baseUrl;

  /// Resolvido a cada requisição: o módulo de autenticação registra o seu
  /// TokenProvider depois dos adaptadores, ou nunca.
  final TokenProvider? Function() _tokenProvider;
  final Duration _timeout;
  final http.Client _client;

  @override
  Future<Object?> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  @override
  Future<Object?> post(
    String path, {
    Object? body,
    String? idempotencyKey,
    bool authenticated = true,
  }) => _send(
    'POST',
    path,
    body: body,
    idempotencyKey: idempotencyKey,
    authenticated: authenticated,
  );

  @override
  Future<Object?> put(String path, {Object? body, String? idempotencyKey}) =>
      _send('PUT', path, body: body, idempotencyKey: idempotencyKey);

  @override
  Future<Object?> patch(String path, {Object? body, String? idempotencyKey}) =>
      _send('PATCH', path, body: body, idempotencyKey: idempotencyKey);

  @override
  Future<Object?> delete(String path, {String? idempotencyKey}) =>
      _send('DELETE', path, idempotencyKey: idempotencyKey);

  /// O envio inteiro. Com [authenticated], leva o token quando há um
  /// TokenProvider e uma sessão; diante de um 401 numa requisição que levou
  /// o token, pede um token novo, uma vez, e repete com ele. Sem
  /// [authenticated], é a própria renovação, que não pode pedir outra
  /// (capítulo 27).
  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? idempotencyKey,
    bool authenticated = true,
  }) async {
    // Uma requisição só pode ser enviada uma vez: a repetição depois da
    // renovação monta outra, com o mesmo corpo e a mesma chave.
    http.Request build(String? token) {
      final request = http.Request(method, _uri(path, query))
        ..headers['accept'] = 'application/json';
      if (idempotencyKey != null) {
        request.headers['Idempotency-Key'] = idempotencyKey;
      }
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (body != null) {
        request.headers['content-type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      return request;
    }

    try {
      final provider = authenticated ? _tokenProvider() : null;
      final token = await provider?.currentToken();
      var response = await _fetch(build(token));
      if (response.statusCode == 401 && provider != null && token != null) {
        // Sem token novo, a sessão acabou: o TokenProvider já avisou, e o
        // 401 sobe; o redirect do host leva ao login (capítulo 28). Uma
        // renovação sem rede sobe o seu próprio erro, que é transitório.
        final renewed = await provider.refreshToken();
        if (renewed != null) response = await _fetch(build(renewed));
      }
      return _decode(response);
    } on ApiError {
      rethrow;
    } on Exception {
      // Sem resposta depois das tentativas: sem rede, tempo esgotado,
      // conexão recusada, certificado recusado.
      throw const ApiError(ApiErrorKind.unreachable);
    }
  }

  Uri _uri(String path, Map<String, String>? query) {
    final uri = Uri.parse('$_baseUrl$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<http.Response> _fetch(http.Request request) async {
    final streamed = await _client.send(request);
    return http.Response.fromStream(streamed).timeout(_timeout);
  }

  /// 2xx → o corpo decodificado (null se vazio), ou invalidResponse, nunca
  /// com o corpo, se não for JSON; 5xx → server; outro status → rejected,
  /// os dois com status e corpo.
  static Object? _decode(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (response.bodyBytes.isEmpty) return null;
      try {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw ApiError(ApiErrorKind.invalidResponse, statusCode: status);
      }
    }
    throw ApiError(
      status >= 500 ? ApiErrorKind.server : ApiErrorKind.rejected,
      statusCode: status,
      body: _tryDecode(response.bodyBytes),
    );
  }

  static Object? _tryDecode(List<int> bytes) {
    try {
      return bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return null;
    }
  }

  static bool _isTransport(Object error) =>
      error is http.ClientException ||
      error is IOException ||
      error is TimeoutException;

  /// baseDelay × 2^repetição, mais até um baseDelay de jitter; a repetição
  /// conta a partir de zero.
  static Duration Function(int) _backoff(Duration baseDelay, Random random) =>
      (retry) => baseDelay * pow(2, retry) + baseDelay * random.nextDouble();
}

/// Cada tentativa, uma a uma: o tempo limite e o log. Registra método,
/// caminho, status e duração no [AppLogger]; nunca cabeçalhos, query nem
/// corpos, que é onde estariam tokens e dados pessoais.
final class _AttemptClient extends http.BaseClient {
  _AttemptClient(this._inner, this._logger, this._timeout);

  final http.Client _inner;
  final AppLogger _logger;
  final Duration _timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final watch = Stopwatch()..start();
    final what = '${request.method} ${request.url.path}';
    try {
      final response = await _inner.send(request).timeout(_timeout);
      _logger.log(
        '$what → ${response.statusCode} (${watch.elapsedMilliseconds} ms)',
      );
      return response;
    } catch (_) {
      // Um breadcrumb, não um erro registrado: quem trata o ApiError decide
      // se vale reportá-lo.
      _logger.log('$what → sem resposta (${watch.elapsedMilliseconds} ms)');
      rethrow;
    }
  }

  @override
  void close() => _inner.close();
}
