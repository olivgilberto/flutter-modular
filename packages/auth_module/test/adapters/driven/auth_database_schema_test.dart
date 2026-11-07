import 'dart:io';

import 'package:auth_module/adapters/driven/services/auth_database_schema.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/ffi_local_database.dart';

/// Cada versão do auth.db que já chegou a algum aparelho, copiada no dia
/// em que saiu e nunca mais alterada (capítulo 30). A versão 1 é a do
/// capítulo 21, anterior a este teste.
const _published = <int, List<String>>{
  1: [
    '''
      CREATE TABLE session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        access_token TEXT NOT NULL,
        refresh_token TEXT NOT NULL
      )
      ''',
  ],
  2: [
    '''
    CREATE TABLE session (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      email TEXT NOT NULL,
      access_token TEXT NOT NULL,
      refresh_token TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE data_owner (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      user_id TEXT NOT NULL
    )
    ''',
  ],
};

DatabaseSchema _publishedSchema(int version) => DatabaseSchema(
  name: authDatabaseSchema.name,
  version: version,
  createStatements: _published[version]!,
);

/// O esquema como o SQLite o entende: as colunas de cada tabela, os
/// índices e o texto de cada CHECK, sem depender de espaços e quebras de
/// linha.
Future<Map<String, Object?>> _describe(Database db) async {
  final description = <String, Object?>{};
  final objects = await db.rawQuery(
    "SELECT type, name, tbl_name, sql FROM sqlite_master "
    "WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name",
  );
  for (final object in objects) {
    final name = object['name']! as String;
    if (object['type'] == 'table') {
      final columns = await db.rawQuery('PRAGMA table_info("$name")');
      description['table $name'] = [
        for (final c in columns)
          '${c['name']} ${c['type']} notnull=${c['notnull']} '
              'default=${c['dflt_value']} pk=${c['pk']}',
      ];
      // O conteúdo de cada CHECK, com um nível de parênteses dentro dele.
      final checks = RegExp(r'CHECK\s*\(((?:[^()]|\([^()]*\))*)\)')
          .allMatches(object['sql']! as String)
          .map((m) => m.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim());
      description['checks $name'] = checks.toList()..sort();
    } else if (object['type'] == 'index') {
      final columns = await db.rawQuery('PRAGMA index_info("$name")');
      description['index $name on ${object['tbl_name']}'] = [
        for (final c in columns) c['name'],
      ];
    }
  }
  return description;
}

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('auth_schema');
  });
  tearDown(() => directory.delete(recursive: true));

  /// Uma pasta nova dentro da temporária do teste.
  Future<String> folder(String name) async {
    final path = '${directory.path}/$name';
    await Directory(path).create();
    return path;
  }

  /// Uma instalação nova, com o esquema completo da versão atual.
  Future<Map<String, Object?>> installFresh() async {
    final factory = FfiLocalDatabaseFactory(directory: await folder('fresh'));
    final description = await _describe(
      await factory.rawDatabase(authDatabaseSchema),
    );
    await factory.close();
    return description;
  }

  test('a versão atual tem a sua cópia publicada, e a instalação nova é '
      'igual a ela', () async {
    expect(
      _published.keys,
      contains(authDatabaseSchema.version),
      reason: 'Uma versão nova precisa da sua cópia em _published.',
    );

    final factory = FfiLocalDatabaseFactory(directory: directory.path);
    final copy = await _describe(
      await factory.rawDatabase(_publishedSchema(authDatabaseSchema.version)),
    );
    await factory.close();

    expect(await installFresh(), copy);
  });

  test('cada versão publicada chega à atual pelas migrações', () async {
    final expected = await installFresh();
    final older = _published.keys.where((v) => v < authDatabaseSchema.version);
    expect(older, isNotEmpty);

    for (final version in older) {
      final path = await folder('v$version');
      final old = FfiLocalDatabaseFactory(directory: path);
      await old.rawDatabase(_publishedSchema(version));
      await old.close();

      final upgraded = FfiLocalDatabaseFactory(directory: path);
      expect(
        await _describe(await upgraded.rawDatabase(authDatabaseSchema)),
        expected,
        reason: 'atualização a partir da versão $version',
      );
      await upgraded.close();
    }
  });

  test('a migração 2 mantém a sessão guardada e começa sem dono', () async {
    final path = await folder('dados');
    final old = FfiLocalDatabaseFactory(directory: path);
    final v1 = await old.rawDatabase(_publishedSchema(1));
    await v1.execute(
      "INSERT INTO session VALUES (1, 'u-1', 'Ana', 'ana@exemplo.com', "
      "'at-1', 'rt-1')",
    );
    await old.close();

    final upgraded = FfiLocalDatabaseFactory(directory: path);
    final db = await upgraded.rawDatabase(authDatabaseSchema);
    expect(await db.rawQuery('SELECT user_id FROM session'), [
      {'user_id': 'u-1'},
    ]);
    expect(await db.rawQuery('SELECT * FROM data_owner'), isEmpty);
    await upgraded.close();
  });
}
