import 'package:core/core.dart';

import '../auth_api_paths.dart';
import 'auth_token_remote_service.dart';

final class RestAuthTokenService implements AuthTokenRemoteService {
  RestAuthTokenService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  @override
  Future<({String accessToken, String refreshToken})> renew(
    String refreshToken,
  ) async {
    // Sem o token de acesso, que é o que venceu: um 401 aqui não pode pedir
    // outra renovação (capítulo 27).
    final json = await _api.post(
      AuthApiPaths.refresh,
      body: {'refreshToken': refreshToken},
      authenticated: false,
    );
    if (json case {
      'accessToken': String accessToken,
      'refreshToken': String refreshToken,
    }) {
      return (accessToken: accessToken, refreshToken: refreshToken);
    }
    throw const ApiError(ApiErrorKind.invalidResponse);
  }
}
