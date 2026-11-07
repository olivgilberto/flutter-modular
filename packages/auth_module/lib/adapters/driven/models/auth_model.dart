import '../../../domain/entities/user.dart';
import '../../../domain/value_objects/email_address.dart';

/// A sessão como o backend a entrega e como o banco local a guarda: o
/// usuário e os dois tokens. Serialização escrita à mão, nos dois formatos.
final class AuthModel {
  const AuthModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
  });

  /// A resposta do login e do cadastro. Chaves a mais são ignoradas; uma
  /// chave a menos, ou de outro tipo, é [FormatException].
  factory AuthModel.fromJson(Object? json) {
    if (json case {
      'user': {'id': String userId, 'name': String name, 'email': String email},
      'accessToken': String accessToken,
      'refreshToken': String refreshToken,
    }) {
      return AuthModel(
        userId: userId,
        name: name,
        email: email,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    }
    throw const FormatException('Resposta de autenticação fora do formato');
  }

  /// A linha da tabela `session` do banco do módulo.
  factory AuthModel.fromMap(Map<String, Object?> row) {
    if (row case {
      'user_id': String userId,
      'name': String name,
      'email': String email,
      'access_token': String accessToken,
      'refresh_token': String refreshToken,
    }) {
      return AuthModel(
        userId: userId,
        name: name,
        email: email,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    }
    throw const FormatException('Sessão guardada fora do formato');
  }

  final String userId;
  final String name;
  final String email;
  final String accessToken;
  final String refreshToken;

  Map<String, Object?> toMap() => {
    'user_id': userId,
    'name': name,
    'email': email,
    'access_token': accessToken,
    'refresh_token': refreshToken,
  };

  /// A mesma sessão com os tokens renovados.
  AuthModel withTokens({
    required String accessToken,
    required String refreshToken,
  }) => AuthModel(
    userId: userId,
    name: name,
    email: email,
    accessToken: accessToken,
    refreshToken: refreshToken,
  );

  /// Pode lançar `InvalidEmailFailure`: quem chama decide o que isso
  /// significa, porque o dado veio de fora (capítulo 9).
  User toEntity() =>
      User(id: userId, name: name, email: EmailAddress.parse(email));
}
