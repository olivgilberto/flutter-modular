import 'package:core/core.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  group('DefaultOutboxRegistry', () {
    test('soma as pendências de todas as filas', () async {
      final registry = DefaultOutboxRegistry()
        ..register(FakeOutbox('tasks', pending: 2))
        ..register(FakeOutbox('notes', pending: 3));

      expect(await registry.pendingOperations(), 5);
    });

    test('unregisterAll esvazia o registry', () async {
      final registry = DefaultOutboxRegistry()
        ..register(FakeOutbox('tasks', pending: 2))
        ..unregisterAll();

      expect(registry.outboxes, isEmpty);
      expect(await registry.pendingOperations(), 0);
    });
  });

  group('OutboxSyncWorker', () {
    late DefaultOutboxRegistry registry;
    late FakeLogger logger;
    late OutboxSyncWorker worker;

    setUp(() {
      registry = DefaultOutboxRegistry();
      logger = FakeLogger();
      worker = OutboxSyncWorker(registry: registry, logger: logger);
    });

    test('sem filas, nada fica para depois', () async {
      expect(await worker.run(), isFalse);
    });

    test('uma fila com algo a reenviar pede nova rodada', () async {
      registry
        ..register(FakeOutbox('tasks'))
        ..register(FakeOutbox('notes', result: true));

      expect(await worker.run(), isTrue);
    });

    test('LocalDatabaseError numa fila não impede as outras', () async {
      final broken = FakeOutbox(
        'tasks',
        throws: const LocalDatabaseError('corrompido'),
      );
      final healthy = FakeOutbox('notes');
      registry
        ..register(broken)
        ..register(healthy);

      expect(await worker.run(), isTrue);
      expect(healthy.calls, 1);
      expect(logger.errors, ['outbox tasks']);
    });

    test('um bug é relançado depois que as outras filas terminam', () async {
      final buggy = FakeOutbox('tasks', throws: StateError('bug'));
      final healthy = FakeOutbox('notes');
      registry
        ..register(buggy)
        ..register(healthy);

      await expectLater(worker.run(), throwsA(isA<StateError>()));
      expect(healthy.calls, 1);
      expect(logger.errors, isEmpty);
    });
  });
}
