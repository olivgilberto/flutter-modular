/// A porta HTTP. Devolve o corpo da resposta já decodificado e lança
/// [ApiError] em qualquer falha; nenhum tipo de biblioteca HTTP passa por
/// aqui.
abstract interface class ApiClient {
  Future<Object?> get(String path, {Map<String, String>? query});

  /// [idempotencyKey] vai no cabeçalho Idempotency-Key e é mantido nas
  /// novas tentativas. É só transporte: a garantia de "uma vez só" vem do
  /// desenho das operações (capítulo 12).
  ///
  /// [authenticated] falso manda a requisição sem o token e sem a renovação
  /// diante de um 401: é o caso da própria renovação (capítulo 27).
  Future<Object?> post(
    String path, {
    Object? body,
    String? idempotencyKey,
    bool authenticated = true,
  });
  Future<Object?> put(String path, {Object? body, String? idempotencyKey});
  Future<Object?> patch(String path, {Object? body, String? idempotencyKey});
  Future<Object?> delete(String path, {String? idempotencyKey});
}

enum ApiErrorKind {
  /// A requisição não chegou ou a resposta não voltou: sem rede,
  /// tempo esgotado, certificado recusado.
  unreachable,

  /// O servidor respondeu 5xx.
  server,

  /// O servidor recusou a requisição com 4xx.
  rejected,

  /// A resposta chegou, mas fora do formato esperado. Nunca carrega o corpo.
  invalidResponse,
}

final class ApiError implements Exception {
  const ApiError(this.kind, {this.statusCode, this.body});

  final ApiErrorKind kind;
  final int? statusCode;
  final Object? body;

  /// O que vale tentar de novo: a decisão do retry e da fila de envio.
  bool get isTransient => switch (kind) {
    ApiErrorKind.unreachable || ApiErrorKind.server => true,
    ApiErrorKind.rejected || ApiErrorKind.invalidResponse => false,
  };

  @override
  String toString() => 'ApiError(${kind.name}, statusCode: $statusCode)';
}
