import '../../domain/entities/user.dart';
import '../../domain/value_objects/email_address.dart';
import '../../domain/value_objects/password.dart';

/// A porta driven da autenticação: o que o módulo precisa do mundo
/// exterior, nos termos dele. Falhas técnicas chegam como os erros do
/// `core` (`ApiError`, `LocalDatabaseError`).
abstract interface class AuthRepository {
  /// Lança `InvalidCredentialsFailure` quando o backend recusa o e-mail e
  /// a senha.
  Future<User> signInWithPassword(EmailAddress email, Password password);

  /// Lança `EmailAlreadyRegisteredFailure` quando o e-mail já existe e
  /// `WeakPasswordFailure` quando o backend recusa a senha.
  Future<User> registerAccount({
    required String name,
    required EmailAddress email,
    required Password password,
  });

  /// O usuário da sessão guardada no aparelho, ou `null` se não houver.
  Future<User?> restoreSession();

  /// Encerra a sessão no backend e descarta o token local.
  Future<void> signOut();

  /// Emite quando a sessão expira sem poder ser renovada (capítulo 11).
  Stream<void> watchSessionExpired();
}
