import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tasks_module/adapters/driven/services/tasks_database_schema.dart';

import '../../support/ffi_local_database.dart';

/// Cada versão do tasks.db que já chegou a algum aparelho, copiada no dia
/// em que saiu e nunca mais alterada. Uma mudança no esquema sobe a versão
/// e acrescenta uma entrada aqui; as antigas ficam como estão.
const _published = <int, List<String>>{
  1: [
    '''
    CREATE TABLE tasks (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      status TEXT NOT NULL CHECK (status IN ('open', 'done', 'archived')),
      created_at INTEGER NOT NULL
    )
    ''',
    'CREATE INDEX tasks_by_status ON tasks (status, created_at)',
    '''
    CREATE TABLE preferences (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    ''',
  ],
  2: [
    '''
    CREATE TABLE tasks (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      status TEXT NOT NULL CHECK (status IN ('open', 'done', 'archived')),
      created_at INTEGER NOT NULL,
      version INTEGER NOT NULL DEFAULT 0
    )
    ''',
    'CREATE INDEX tasks_by_status ON tasks (status, created_at)',
    '''
    CREATE TABLE preferences (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE outbox_pending_operations (
      id TEXT PRIMARY KEY,
      entity_id TEXT NOT NULL,
      operation TEXT NOT NULL CHECK (operation IN ('create', 'update', 'archive')),
      payload TEXT NOT NULL,
      base_version INTEGER,
      created_at INTEGER NOT NULL
    )
    ''',
    'CREATE INDEX outbox_by_entity ON outbox_pending_operations (entity_id)',
    '''
    CREATE TABLE sync_state (
      key TEXT PRIMARY KEY,
      refreshed_at INTEGER NOT NULL
    )
    ''',
  ],
  3: [
    '''
    CREATE TABLE tasks (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      status TEXT NOT NULL CHECK (status IN ('open', 'done', 'archived')),
      created_at INTEGER NOT NULL,
      version INTEGER NOT NULL DEFAULT 0
    )
    ''',
    'CREATE INDEX tasks_by_status ON tasks (status, created_at)',
    '''
    CREATE TABLE preferences (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE outbox_pending_operations (
      id TEXT PRIMARY KEY,
      entity_id TEXT NOT NULL,
      operation TEXT NOT NULL CHECK (operation IN ('create', 'update', 'archive')),
      payload TEXT NOT NULL,
      base_version INTEGER,
      created_at INTEGER NOT NULL
    )
    ''',
    'CREATE INDEX outbox_by_entity ON outbox_pending_operations (entity_id)',
    '''
    CREATE TABLE sync_state (
      key TEXT PRIMARY KEY,
      refreshed_at INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE sync_conflicts (
      id TEXT PRIMARY KEY,
      operation_id TEXT NOT NULL UNIQUE,
      entity_id TEXT NOT NULL,
      kind TEXT NOT NULL CHECK (kind IN ('conflict', 'rejected')),
      status_code INTEGER NOT NULL,
      operation TEXT NOT NULL CHECK (operation IN ('create', 'update', 'archive')),
      payload TEXT NOT NULL,
      base_version INTEGER,
      created_at INTEGER NOT NULL
    )
    ''',
    'CREATE INDEX sync_conflicts_by_entity ON sync_conflicts (entity_id)',
  ],
};

DatabaseSchema _publishedSchema(int version) => DatabaseSchema(
  name: tasksDatabaseSchema.name,
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
    directory = await Directory.systemTemp.createTemp('tasks_schema');
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
      await factory.rawDatabase(tasksDatabaseSchema),
    );
    await factory.close();
    return description;
  }

  test('a versão atual tem a sua cópia publicada, e a instalação nova é '
      'igual a ela', () async {
    expect(
      _published.keys,
      contains(tasksDatabaseSchema.version),
      reason: 'Uma versão nova precisa da sua cópia em _published.',
    );

    final factory = FfiLocalDatabaseFactory(directory: directory.path);
    final copy = await _describe(
      await factory.rawDatabase(_publishedSchema(tasksDatabaseSchema.version)),
    );
    await factory.close();

    expect(await installFresh(), copy);
  });

  test('cada versão publicada chega à atual pelas migrações', () async {
    final expected = await installFresh();
    final older = _published.keys.where((v) => v < tasksDatabaseSchema.version);
    expect(older, isNotEmpty);

    for (final version in older) {
      final path = await folder('v$version');
      final old = FfiLocalDatabaseFactory(directory: path);
      await old.rawDatabase(_publishedSchema(version));
      await old.close();

      final upgraded = FfiLocalDatabaseFactory(directory: path);
      expect(
        await _describe(await upgraded.rawDatabase(tasksDatabaseSchema)),
        expected,
        reason: 'atualização a partir da versão $version',
      );
      await upgraded.close();
    }
  });

  test('a migração 2 preserva as tarefas da versão 1 e põe a criação de '
      'cada uma na fila, na ordem em que foram criadas', () async {
    final path = await folder('dados');
    final old = FfiLocalDatabaseFactory(directory: path);
    final v1 = await old.rawDatabase(_publishedSchema(1));
    // 2026-10-27 09:00 e 09:01 UTC, em milissegundos.
    await v1.execute(
      "INSERT INTO tasks VALUES ('t-2', 'Pagar a luz', 'done', 1793091660000)",
    );
    await v1.execute(
      "INSERT INTO tasks VALUES ('t-1', 'Comprar pão', 'open', 1793091600000)",
    );
    await old.close();

    final upgraded = FfiLocalDatabaseFactory(directory: path);
    final db = await upgraded.rawDatabase(tasksDatabaseSchema);
    expect(await db.rawQuery('SELECT id, version FROM tasks ORDER BY id'), [
      {'id': 't-1', 'version': 0},
      {'id': 't-2', 'version': 0},
    ]);
    final operations = await db.rawQuery(
      'SELECT * FROM outbox_pending_operations ORDER BY rowid',
    );
    expect([for (final op in operations) op['entity_id']], ['t-1', 't-2']);
    for (final op in operations) {
      expect(op['operation'], 'create');
      expect(op['base_version'], isNull);
      expect(
        op['id'],
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    }
    expect(jsonDecode(operations.first['payload']! as String), {
      'title': 'Comprar pão',
      'status': 'open',
      'createdAt': '2026-10-27T09:00:00.000Z',
    });
    await upgraded.close();
  });
}
