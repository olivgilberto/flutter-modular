import 'package:core/core.dart';

import '../models/auth_model.dart';
import 'auth_database_schema.dart';
import 'auth_session_local_service.dart';

/// A sessão no banco criptografado do módulo, aberto pela porta
/// `LocalDatabaseFactory`: a chave do banco fica no Keychain do aparelho, e
/// o arquivo, fora do backup (capítulo 18). Nenhuma tecnologia nova entra
/// no módulo para guardar os tokens.
final class SqliteAuthSessionService implements AuthSessionLocalService {
  SqliteAuthSessionService({required LocalDatabaseFactory databaseFactory})
    : _databaseFactory = databaseFactory;

  /// O banco do módulo, com o dono dos dados ao lado da sessão.
  static const schema = authDatabaseSchema;

  final LocalDatabaseFactory _databaseFactory;

  /// Aberto no primeiro uso, nunca no registro do módulo. A fábrica guarda
  /// o banco aberto e esquece uma abertura que falhou (capítulo 18).
  Future<LocalDatabase> get _database => _databaseFactory.open(schema);

  @override
  Future<AuthModel?> read() async {
    final rows = await (await _database).query(
      'SELECT user_id, name, email, access_token, refresh_token '
      'FROM session WHERE id = 1',
    );
    if (rows.isEmpty) return null;
    try {
      return AuthModel.fromMap(rows.single);
    } on FormatException catch (error) {
      throw LocalDatabaseError('sessão guardada inválida: ${error.message}');
    }
  }

  @override
  Future<void> write(AuthModel session) async {
    final row = session.toMap();
    await (await _database).execute(
      'INSERT OR REPLACE INTO session '
      '(id, user_id, name, email, access_token, refresh_token) '
      'VALUES (1, ?, ?, ?, ?, ?)',
      args: [
        row['user_id'],
        row['name'],
        row['email'],
        row['access_token'],
        row['refresh_token'],
      ],
    );
  }

  @override
  Future<void> delete() async {
    await (await _database).execute('DELETE FROM session');
  }
}
