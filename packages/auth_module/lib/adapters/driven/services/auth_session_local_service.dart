import '../models/auth_model.dart';

/// A fonte local da sessão: uma única linha, que sobrevive ao fechamento
/// do app e pode ser lida pela sincronização em segundo plano.
abstract interface class AuthSessionLocalService {
  Future<AuthModel?> read();
  Future<void> write(AuthModel session);
  Future<void> delete();
}
