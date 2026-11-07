import 'package:core/core.dart';

/// O banco do módulo de tarefas (capítulo 30). Regras para mudá-lo:
///
/// - `createStatements` é sempre o esquema completo da versão atual, para
///   quem instala o app agora;
/// - toda mudança sobe `version` e ganha, em `migrations`, os comandos que
///   levam da versão anterior até ela, inclusive a correção de dados que a
///   regra nova recusaria;
/// - uma versão que já chegou a algum aparelho nunca muda. O teste de
///   esquema guarda uma cópia de cada uma e confere que a instalação nova e
///   a atualização chegam ao mesmo lugar.
///
/// Versões: 1, as tarefas e as preferências (capítulo 30); 2, a versão do
/// servidor em cada tarefa, a fila de envio e a hora da última atualização
/// (capítulo 31); 3, as operações que o servidor recusou, à espera da
/// decisão do usuário (capítulo 32).
const tasksDatabaseSchema = DatabaseSchema(
  name: 'tasks.db',
  version: 3,
  createStatements: [
    // A coluna version fica no fim, onde o ALTER TABLE da migração 2 a
    // põe: a instalação nova e a atualização têm a mesma ordem.
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
    _createOutbox,
    _createOutboxIndex,
    _createSyncState,
    _createConflicts,
    _createConflictsIndex,
  ],
  migrations: {
    2: [
      'ALTER TABLE tasks ADD COLUMN version INTEGER NOT NULL DEFAULT 0',
      _createOutbox,
      _createOutboxIndex,
      _createSyncState,
      _enqueueVersion1Tasks,
    ],
    3: [_createConflicts, _createConflictsIndex],
  },
);

/// A fila de envio (capítulo 12): uma linha por operação feita no
/// aparelho e ainda não aceita pelo backend, gravada na mesma transação que
/// altera a tarefa. A ordem de envio é a de gravação, o `rowid`.
const _createOutbox = '''
    CREATE TABLE outbox_pending_operations (
      id TEXT PRIMARY KEY,
      entity_id TEXT NOT NULL,
      operation TEXT NOT NULL CHECK (operation IN ('create', 'update', 'archive')),
      payload TEXT NOT NULL,
      base_version INTEGER,
      created_at INTEGER NOT NULL
    )
    ''';

const _createOutboxIndex =
    'CREATE INDEX outbox_by_entity ON outbox_pending_operations (entity_id)';

/// O que o servidor recusou (capítulo 12): `conflict` para um 409 de versão,
/// `rejected` para outra recusa. A operação sai da fila e vem para cá na
/// mesma transação, como estava, até o usuário decidir (capítulo 34). O
/// `operation_id` é único: o segundo isolate que receber a mesma recusa
/// não grava outra cópia.
const _createConflicts = '''
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
    ''';

const _createConflictsIndex =
    'CREATE INDEX sync_conflicts_by_entity ON sync_conflicts (entity_id)';

/// Quando cada lista veio do backend pela última vez: a resposta a "já
/// carreguei alguma vez?" e a base do TTL.
const _createSyncState = '''
    CREATE TABLE sync_state (
      key TEXT PRIMARY KEY,
      refreshed_at INTEGER NOT NULL
    )
    ''';

/// A correção de dados da migração 2. Na versão 1 o módulo ainda não
/// falava com o backend, e toda tarefa guardada só existia no aparelho.
/// Sem uma operação na fila, a primeira atualização a apagaria, porque ela
/// não vem na lista do servidor. Cada uma ganha a criação que faltou, na
/// ordem em que foi criada, com o mesmo formato que o serviço grava.
const _enqueueVersion1Tasks = """
    INSERT INTO outbox_pending_operations
      (id, entity_id, operation, payload, base_version, created_at)
    SELECT
      lower(
        hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' ||
        substr(hex(randomblob(2)), 2) || '-' ||
        substr('89ab', 1 + (random() & 3), 1) ||
        substr(hex(randomblob(2)), 2) || '-' || hex(randomblob(6))
      ),
      id,
      'create',
      json_object(
        'title', title,
        'status', status,
        'createdAt',
        strftime('%Y-%m-%dT%H:%M:%fZ', created_at / 1000.0, 'unixepoch')
      ),
      NULL,
      CAST(strftime('%s', 'now') AS INTEGER) * 1000
    FROM tasks
    ORDER BY created_at, id
    """;
