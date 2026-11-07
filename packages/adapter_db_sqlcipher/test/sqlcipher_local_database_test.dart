import 'package:adapter_db_sqlcipher/adapter_db_sqlcipher.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// O SqlcipherLocalDatabase só usa a API comum do sqflite, então roda no
/// computador sobre um banco em memória do sqflite_common_ffi. A
/// criptografia em si só existe no aparelho.
void main() {
  late Database raw;
  late LocalDatabase database;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    raw = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    database = SqlcipherLocalDatabase(raw);
    await database.execute(
      'CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL)',
    );
  });

  tearDown(() => raw.close());

  test('grava e lê', () async {
    await database.execute(
      'INSERT INTO tasks (id, title) VALUES (?, ?)',
      args: ['1', 'Comprar pão'],
    );

    expect(await database.query('SELECT title FROM tasks'), [
      {'title': 'Comprar pão'},
    ]);
  });

  test('uma falha dentro da transação desfaz tudo', () async {
    await expectLater(
      database.transaction((txn) async {
        await txn.execute("INSERT INTO tasks VALUES ('1', 'a')");
        throw StateError('falha no meio');
      }),
      throwsA(isA<StateError>()),
    );

    expect(await database.query('SELECT * FROM tasks'), isEmpty);
  });

  test('uma transação aninhada entra na de fora', () async {
    await expectLater(
      database.transaction((outer) async {
        await outer.execute("INSERT INTO tasks VALUES ('1', 'a')");
        await outer.transaction(
          (inner) => inner.execute("INSERT INTO tasks VALUES ('2', 'b')"),
        );
        throw StateError('desfaz as duas');
      }),
      throwsA(isA<StateError>()),
    );

    expect(await database.query('SELECT * FROM tasks'), isEmpty);
  });

  test('erro do driver vira LocalDatabaseError', () async {
    await expectLater(
      database.execute("INSERT INTO tasks VALUES ('1', NULL)"),
      throwsA(isA<LocalDatabaseError>()),
    );
    await expectLater(
      database.query('SELECT * FROM nao_existe'),
      throwsA(isA<LocalDatabaseError>()),
    );
  });
}
