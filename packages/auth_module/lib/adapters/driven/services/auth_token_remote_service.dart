/// A fonte remota da renovação de tokens.
abstract interface class AuthTokenRemoteService {
  /// Troca o token de renovação por um par novo. Lança `ApiError` do tipo
  /// `rejected` quando o backend não aceita mais a sessão.
  Future<({String accessToken, String refreshToken})> renew(
    String refreshToken,
  );
}
