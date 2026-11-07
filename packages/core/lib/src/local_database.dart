/// Um banco local de um módulo. Todo método lança [LocalDatabaseError] em
/// caso de falha; nenhuma exceção do driver passa por aqui.
abstract interface class LocalDatabase {
  Future<List<Map<String, Object?>>> query(String sql, {List<Object?>? args});
  Future<void> execute(String sql, {List<Object?>? args});

  /// Roda [action] numa transação. Dentro de uma transação, uma chamada
  /// aninhada entra na mesma transação em vez de abrir outra.
  Future<T> transaction<T>(Future<T> Function(LocalDatabase txn) action);
}

/// Abre o banco de cada módulo. Um banco por módulo, nunca compartilhado.
abstract interface class LocalDatabaseFactory {
  Future<LocalDatabase> open(DatabaseSchema schema);
}

/// O que um módulo declara sobre o seu banco: nome, versão, o esquema
/// completo para instalações novas e as migrações para atualizações.
final class DatabaseSchema {
  const DatabaseSchema({
    required this.name,
    required this.version,
    required this.createStatements,
    this.migrations = const {},
  });

  /// Nome do arquivo, único no app (por exemplo, 'tasks.db').
  final String name;
  final int version;

  /// O esquema da versão atual, para quem instala o app agora.
  final List<String> createStatements;

  /// Para cada versão, os comandos que levam da anterior até ela.
  final Map<int, List<String>> migrations;
}

final class LocalDatabaseError implements Exception {
  const LocalDatabaseError(this.message);

  final String message;

  @override
  String toString() => 'LocalDatabaseError($message)';
}
