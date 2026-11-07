import 'package:adapter_sync_workmanager/adapter_sync_workmanager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:workmanager/workmanager.dart';

final class _MockWorkmanager extends Mock implements Workmanager {}

void _dispatcher() {}

void main() {
  setUpAll(
    () => registerFallbackValue(
      Constraints(networkType: NetworkType.notRequired),
    ),
  );

  test('agenda a tarefa periódica, só com rede, sem duplicar', () async {
    final workmanager = _MockWorkmanager();
    when(() => workmanager.initialize(_dispatcher)).thenAnswer((_) async {});
    when(
      () => workmanager.registerPeriodicTask(
        'outbox_sync',
        'outbox_sync',
        frequency: const Duration(hours: 1),
        constraints: any(named: 'constraints'),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      ),
    ).thenAnswer((_) async {});

    await WorkmanagerSyncScheduler(
      callbackDispatcher: _dispatcher,
      workmanager: workmanager,
    ).schedulePeriodicSync();

    verify(() => workmanager.initialize(_dispatcher)).called(1);
    final constraints =
        verify(
              () => workmanager.registerPeriodicTask(
                'outbox_sync',
                'outbox_sync',
                frequency: const Duration(hours: 1),
                constraints: captureAny(named: 'constraints'),
                existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
              ),
            ).captured.single
            as Constraints;
    expect(constraints.networkType, NetworkType.connected);
  });
}
