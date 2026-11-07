# adapter_db_sqlcipher

O banco local criptografado de cada módulo, com SQLCipher.

- **Contém:** `SqlcipherLocalDatabaseFactory` (porta
  `LocalDatabaseFactory`), que abre um banco por módulo com chave própria
  guardada no armazenamento seguro, e `SqlcipherLocalDatabase` (porta
  `LocalDatabase`).
- **Nunca contém:** tabelas, consultas ou migrações de um módulo (cada
  módulo declara as suas num `DatabaseSchema`), nem o registro no get_it.
  Nenhuma exceção do driver sai deste pacote: toda falha vira
  `LocalDatabaseError`.
