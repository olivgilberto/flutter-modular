import 'package:adapter_db_sqlcipher/adapter_db_sqlcipher.dart';
import 'package:flutter_test/flutter_test.dart';

/// As duas constantes combinam com o host (AppDelegate.swift); mudá-las
/// sem mudar o host deixaria bancos ou chaves irem para o backup.
void main() {
  test('os bancos ficam em local_databases', () {
    expect(SqlcipherLocalDatabaseFactory.directoryName, 'local_databases');
  });

  test('a chave só existe neste aparelho', () {
    expect(
      SqlcipherLocalDatabaseFactory.keychainOptions.toMap()['accessibility'],
      'first_unlock_this_device',
    );
  });

  test('cada chave nova tem 256 bits e não se repete', () {
    final first = SqlcipherLocalDatabaseFactory.newKey();
    final second = SqlcipherLocalDatabaseFactory.newKey();

    expect(first, hasLength(44)); // 32 bytes em base64url
    expect(first, isNot(second));
  });
}
