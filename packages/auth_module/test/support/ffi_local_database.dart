import 'package:core/core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A porta `LocalDatabaseFactory` sobre o SQLite do computador, só para
/// testes: o módulo nunca depende do adaptador SQLCipher, nem aqui. Abre
/// como o adaptador abre (capítulo 18): instalação nova roda o esquema
/// completo, atualização roda as migrações pendentes, transações de
/// verdade, e um erro do driver vira `LocalDatabaseError`.
///
/// Sem isolate (capítulo 23): nos testes de widget o relógio é simulado, e
/// uma resposta vinda de outro isolate nunca chegaria.
final class FfiLocalDatabaseFactory implements LocalDatabaseFactory {
  /// Em memória, a não ser que [directory] seja informado.
  FfiLocalDatabaseFactory({this.directory}) {
    sqfliteFfiInit();
  }

  final String? directory;
  final _opened = <String, Future<Database>>{};

  @override
  Future<LocalDatabase> open(DatabaseSchema schema) async =>
      FfiLocalDatabase(await rawDatabase(schema));

  /// O banco do driver, para os testes que inspecionam o esquema.
  Future<Database> rawDatabase(DatabaseSchema schema) =>
      _opened[schema.name] ??= databaseFactoryFfiNoIsolate.openDatabase(
        directory == null ? inMemoryDatabasePath : '$directory/${schema.name}',
        options: OpenDatabaseOptions(
          version: schema.version,
          singleInstance: false,
          onCreate: (db, _) async {
            for (final statement in schema.createStatements) {
              await db.execute(statement);
            }
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            for (var v = oldVersion + 1; v <= newVersion; v++) {
              for (final statement in schema.migrations[v] ?? const []) {
                await db.execute(statement);
              }
            }
          },
        ),
      );

  Future<void> close() async {
    for (final database in _opened.values) {
      await (await database).close();
    }
    _opened.clear();
  }
}

final class FfiLocalDatabase implements LocalDatabase {
  FfiLocalDatabase(this._executor);

  final DatabaseExecutor _executor;

  @override
  Future<List<Map<String, Object?>>> query(String sql, {List<Object?>? args}) =>
      _guard(() => _executor.rawQuery(sql, args));

  @override
  Future<void> execute(String sql, {List<Object?>? args}) =>
      _guard(() => _executor.execute(sql, args));

  @override
  Future<T> transaction<T>(Future<T> Function(LocalDatabase txn) action) {
    final executor = _executor;
    if (executor is! Database) return action(this);
    return _guard(
      () => executor.transaction((txn) => action(FfiLocalDatabase(txn))),
    );
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on DatabaseException catch (exception) {
      throw LocalDatabaseError(exception.toString());
    }
  }
}
