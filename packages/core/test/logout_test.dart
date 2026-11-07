import 'package:core/core.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  test('um cleaner que falha não impede os outros', () async {
    final registry = DefaultLogoutCleanerRegistry();
    final failing = FakeCleaner(throws: const LocalDatabaseError('falhou'));
    final next = FakeCleaner();
    registry
      ..register(failing)
      ..register(next);

    await expectLater(registry.clearAll(), throwsA(isA<LocalDatabaseError>()));
    expect(next.cleared, isTrue);
  });

  test('unregisterAll esquece os cleaners da sessão', () async {
    final registry = DefaultLogoutCleanerRegistry();
    final cleaner = FakeCleaner();
    registry
      ..register(cleaner)
      ..unregisterAll();

    await registry.clearAll();
    expect(cleaner.cleared, isFalse);
  });
}
