import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'sqlcipher_local_database.dart';

/// Abre um banco criptografado por módulo. Cada banco tem a sua chave
/// aleatória de 256 bits, criada na primeira abertura e guardada no
/// armazenamento seguro; nunca uma chave fixa no código. Instalação nova
/// roda `createStatements`; atualização roda as `migrations` pendentes, em
/// ordem de versão.
///
/// Os arquivos ficam em [directoryName], dentro do Application Support do
/// app, nunca em Documents. O host exclui essa pasta do backup (capítulo
/// 30): no iOS pelo `AppDelegate.swift`, no Android pelas regras de
/// extração de dados do manifesto.
final class SqlcipherLocalDatabaseFactory implements LocalDatabaseFactory {
  SqlcipherLocalDatabaseFactory({FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(iOptions: keychainOptions);

  /// Pasta dentro de `getApplicationSupportDirectory()`. Precisa ser o
  /// mesmo nome que o host exclui do backup, no `AppDelegate.swift` e no
  /// `data_extraction_rules.xml` (capítulo 30); mudá-lo num app publicado
  /// exige migrar os arquivos.
  static const directoryName = 'local_databases';

  /// Legível depois do primeiro desbloqueio desde a inicialização, para que
  /// a sincronização em segundo plano abra o banco com o aparelho
  /// bloqueado; nunca vai para backup nem para outro aparelho.
  static const keychainOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  final FlutterSecureStorage _secureStorage;
  final Map<String, Future<LocalDatabase>> _opened = {};

  /// Chamadas simultâneas para o mesmo banco compartilham a abertura. Uma
  /// abertura que falhou é esquecida, para que a próxima tente de novo.
  @override
  Future<LocalDatabase> open(DatabaseSchema schema) => _opened[schema.name] ??=
      _open(schema).catchError((Object error, StackTrace stackTrace) {
        _opened.remove(schema.name);
        Error.throwWithStackTrace(error, stackTrace);
      });

  Future<LocalDatabase> _open(DatabaseSchema schema) async {
    try {
      final directory = Directory(
        '${(await getApplicationSupportDirectory()).path}/$directoryName',
      );
      await directory.create(recursive: true);
      final database = await openDatabase(
        '${directory.path}/${schema.name}',
        password: await _keyFor(schema.name),
        version: schema.version,
        onCreate: (db, _) async {
          for (final statement in schema.createStatements) {
            await db.execute(statement);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          for (var version = oldVersion + 1; version <= newVersion; version++) {
            for (final statement in schema.migrations[version] ?? const []) {
              await db.execute(statement);
            }
          }
        },
      );
      return SqlcipherLocalDatabase(database);
    } on DatabaseException catch (exception) {
      throw LocalDatabaseError(exception.toString());
    } on FileSystemException catch (exception) {
      throw LocalDatabaseError(exception.toString());
    }
  }

  Future<String> _keyFor(String databaseName) async {
    final storageKey = 'local_database_key.$databaseName';
    final existing = await _secureStorage.read(key: storageKey);
    if (existing != null) return existing;

    final key = newKey();
    await _secureStorage.write(key: storageKey, value: key);
    return key;
  }

  /// 32 bytes de `Random.secure()`, em base64url.
  @visibleForTesting
  static String newKey() {
    final random = Random.secure();
    return base64UrlEncode(List.generate(32, (_) => random.nextInt(256)));
  }
}
