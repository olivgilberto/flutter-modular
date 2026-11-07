import 'package:core/core.dart';

import '../../../application/ports/auth_repository.dart';
import '../../../domain/auth_failure.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/value_objects/email_address.dart';
import '../../../domain/value_objects/password.dart';
import '../auth_api_paths.dart';
import '../auth_session_store.dart';
import '../models/auth_model.dart';

/// A porta [AuthRepository] sobre o backend REST. Uma fonte só, então o
/// Service implementa a porta diretamente (capítulo 8).
final class RestAuthService implements AuthRepository {
  RestAuthService({
    required ApiClient apiClient,
    required AuthSessionStore session,
  }) : _api = apiClient,
       _session = session;

  final ApiClient _api;
  final AuthSessionStore _session;

  @override
  Future<User> signInWithPassword(EmailAddress email, Password password) =>
      _authenticate(
        AuthApiPaths.signIn,
        body: {'email': email.value, 'password': password.value},
      );

  @override
  Future<User> registerAccount({
    required String name,
    required EmailAddress email,
    required Password password,
  }) => _authenticate(
    AuthApiPaths.register,
    body: {'name': name, 'email': email.value, 'password': password.value},
  );

  /// Lida do aparelho, sem rede: o app abre logado mesmo offline.
  @override
  Future<User?> restoreSession() async {
    final stored = await _session.current();
    if (stored == null) return null;
    try {
      return stored.toEntity();
    } on Failure {
      throw const LocalDatabaseError('sessão guardada com e-mail inválido');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _api.post(AuthApiPaths.signOut);
    } finally {
      await _session.clear();
    }
  }

  @override
  Stream<void> watchSessionExpired() => _session.expirations;

  /// A sessão só é gravada depois que a resposta foi lida inteira: uma
  /// resposta inválida nunca deixa um token guardado.
  Future<User> _authenticate(String path, {required Object body}) async {
    final auth = _readAuth(await _post(path, body: body));
    await _session.save(auth.model);
    return auth.user;
  }

  Future<Object?> _post(String path, {required Object body}) async {
    try {
      return await _api.post(path, body: body);
    } on ApiError catch (error) {
      if (_businessFailureOf(error) case final failure?) throw failure;
      rethrow;
    }
  }

  /// A única conversão de erro técnico em falha de negócio (capítulo 9):
  /// status e código, nunca o texto da mensagem.
  static AuthFailure? _businessFailureOf(ApiError error) => switch (error) {
    ApiError(statusCode: 401, body: {'code': 'invalid_credentials'}) =>
      const InvalidCredentialsFailure(),
    ApiError(statusCode: 422, body: {'code': 'email_already_registered'}) =>
      const EmailAlreadyRegisteredFailure(),
    ApiError(statusCode: 422, body: {'code': 'weak_password'}) =>
      const WeakPasswordFailure(),
    _ => null,
  };

  /// Um dado inválido vindo do servidor é defeito da resposta, não do que o
  /// usuário digitou (capítulo 9).
  static ({AuthModel model, User user}) _readAuth(Object? json) {
    try {
      final model = AuthModel.fromJson(json);
      return (model: model, user: model.toEntity());
    } on FormatException {
      throw const ApiError(ApiErrorKind.invalidResponse);
    } on Failure {
      throw const ApiError(ApiErrorKind.invalidResponse);
    }
  }
}
