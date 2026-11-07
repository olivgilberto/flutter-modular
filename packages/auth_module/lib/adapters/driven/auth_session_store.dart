import 'models/auth_model.dart';

/// O que o `RestAuthService` precisa da sessão além da porta
/// `TokenProvider` do `core`. Interna ao módulo, nunca exportada: nenhum
/// outro módulo pode gravar ou apagar a sessão.
abstract interface class AuthSessionStore {
  /// A sessão guardada, ou `null` se não houver.
  Future<AuthModel?> current();

  Future<void> save(AuthModel session);

  Future<void> clear();

  /// Emite quando a sessão expira sem poder ser renovada.
  Stream<void> get expirations;
}
