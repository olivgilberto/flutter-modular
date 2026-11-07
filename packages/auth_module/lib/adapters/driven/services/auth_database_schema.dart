import 'package:core/core.dart';

/// O banco do módulo de autenticação, com as mesmas regras do `tasks.db`
/// (capítulo 30): `createStatements` é o esquema completo da versão atual,
/// toda mudança sobe a versão e ganha a sua migração, e uma versão que já
/// chegou a algum aparelho nunca muda.
///
/// Versões: 1, a sessão (capítulo 21); 2, o dono dos dados guardados no
/// aparelho (capítulo 32).
const authDatabaseSchema = DatabaseSchema(
  name: 'auth.db',
  version: 2,
  createStatements: [_createSession, _createDataOwner],
  migrations: {
    2: [_createDataOwner],
  },
);

/// Uma linha só: a sessão atual.
const _createSession = '''
    CREATE TABLE session (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      email TEXT NOT NULL,
      access_token TEXT NOT NULL,
      refresh_token TEXT NOT NULL
    )
    ''';

/// Uma linha só, e só o id: de quem são os dados que estão no aparelho.
/// Vive mais que a sessão, que some na expiração; some com os dados.
const _createDataOwner = '''
    CREATE TABLE data_owner (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      user_id TEXT NOT NULL
    )
    ''';
