import 'dart:convert';
import 'dart:io';

import 'package:adapter_db_sqlcipher/adapter_db_sqlcipher.dart';
import 'package:adapter_prefs_shared_preferences/adapter_prefs_shared_preferences.dart';
import 'package:core/core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

/// Os adaptadores contra a tecnologia de verdade (capítulo 39). Os testes
/// do capítulo 18 rodam no computador, com o SQLite do FFI sem
/// criptografia e os plugins simulados; o que só o aparelho tem fica aqui:
/// o SQLCipher cifrando o arquivo, a chave guardada no Keychain ou no
/// Keystore e as preferências gravadas pelo plugin. O host só usa o
/// sqflite_sqlcipher, o flutter_secure_storage e o path_provider aqui,
/// como dependências de desenvolvimento: no app, eles chegam só pelo
/// adaptador.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const schema = DatabaseSchema(
    name: 'integracao.db',
    version: 1,
    createStatements: [
      'CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT NOT NULL)',
    ],
  );
  const storage = FlutterSecureStorage(
    iOptions: SqlcipherLocalDatabaseFactory.keychainOptions,
  );

  Future<File> databaseFile() async => File(
    '${(await getApplicationSupportDirectory()).path}/'
    '${SqlcipherLocalDatabaseFactory.directoryName}/${schema.name}',
  );

  // Cada execução começa sem o banco e sem a chave, e não deixa nenhum dos
  // dois para trás.
  Future<void> clean() async {
    final file = await databaseFile();
    final keyName = 'local_database_key.${schema.name}';
    final key = await storage.read(key: keyName);
    // Uma conexão que um teste deixou aberta fecha antes do arquivo sair.
    if (key != null && await file.exists()) {
      await (await sqlcipher.openDatabase(file.path, password: key)).close();
    }
    for (final path in [
      file.path,
      '${file.path}-wal',
      '${file.path}-journal',
    ]) {
      final part = File(path);
      if (await part.exists()) await part.delete();
    }
    await storage.delete(key: keyName);
  }

  setUp(clean);
  tearDown(clean);

  testWidgets('o arquivo do banco é cifrado: nem o cabeçalho do SQLite nem '
      'o texto gravado aparecem nele', (tester) async {
    final database = await SqlcipherLocalDatabaseFactory().open(schema);
    await database.execute(
      'INSERT INTO notes (body) VALUES (?)',
      args: ['marcador-em-texto-claro'],
    );

    final file = await databaseFile();
    final bytes = await file.readAsBytes();
    // Todo banco SQLite sem cifra começa com "SQLite format 3".
    expect(latin1.decode(bytes.take(15).toList()), isNot('SQLite format 3'));
    // O texto não está no arquivo, nem no diário ao lado, se houver.
    for (final path in [
      file.path,
      '${file.path}-wal',
      '${file.path}-journal',
    ]) {
      final part = File(path);
      if (!await part.exists()) continue;
      expect(
        latin1.decode(await part.readAsBytes()),
        isNot(contains('marcador-em-texto-claro')),
        reason: path,
      );
    }
  });

  testWidgets('a chave fica no armazenamento seguro: fechado o banco, outra '
      'fábrica, como num novo início do app, o abre de novo', (tester) async {
    final first = await SqlcipherLocalDatabaseFactory().open(schema);
    await first.execute(
      'INSERT INTO notes (body) VALUES (?)',
      args: ['guardado'],
    );
    final key = await storage.read(key: 'local_database_key.${schema.name}');
    // 32 bytes em base64url: 44 caracteres.
    expect(key, hasLength(44));

    // O sqflite devolve a mesma conexão a quem abre o mesmo arquivo; para
    // que a segunda fábrica abra de verdade, a primeira conexão fecha.
    final path = (await databaseFile()).path;
    await (await sqlcipher.openDatabase(path, password: key)).close();

    final again = await SqlcipherLocalDatabaseFactory().open(schema);
    expect(await again.query('SELECT body FROM notes'), [
      {'body': 'guardado'},
    ]);
    await (await sqlcipher.openDatabase(path, password: key)).close();
  });

  testWidgets('sem a chave certa, o arquivo não abre', (tester) async {
    final database = await SqlcipherLocalDatabaseFactory().open(schema);
    await database.execute(
      'INSERT INTO notes (body) VALUES (?)',
      args: ['guardado'],
    );
    final path = (await databaseFile()).path;
    final key = await storage.read(key: 'local_database_key.${schema.name}');
    await (await sqlcipher.openDatabase(path, password: key)).close();

    await expectLater(() async {
      final wrong = await sqlcipher.openDatabase(
        path,
        password: 'outra-chave',
        singleInstance: false,
      );
      try {
        await wrong.rawQuery('SELECT count(*) FROM notes');
      } finally {
        await wrong.close();
      }
    }(), throwsA(isA<sqlcipher.DatabaseException>()));
  });

  testWidgets('as preferências gravadas pelo plugin sobrevivem a outra '
      'instância do adaptador', (tester) async {
    await SharedPreferencesAppPreferences().saveLanguageCode('pt-BR');
    await SharedPreferencesAppPreferences().saveThemeMode(AppThemeMode.dark);

    final read = SharedPreferencesAppPreferences();
    expect(await read.languageCode(), 'pt-BR');
    expect(await read.themeMode(), AppThemeMode.dark);
  });
}
