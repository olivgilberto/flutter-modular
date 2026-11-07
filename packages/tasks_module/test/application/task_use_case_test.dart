import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tasks_module/application/ports/task_repository.dart';
import 'package:tasks_module/application/use_cases/task_use_case.dart';
import 'package:tasks_module/domain/entities/task.dart';
import 'package:tasks_module/domain/entities/task_conflict.dart';
import 'package:tasks_module/domain/task_failure.dart';
import 'package:tasks_module/domain/value_objects/task_title.dart';

import '../fakes.dart';

final class _MockTaskRepository extends Mock implements TaskRepository {}

void main() {
  final now = DateTime.utc(2026, 10, 27, 9);
  final bread = Task(
    id: 't-1',
    title: TaskTitle.parse('Comprar pão'),
    createdAt: now,
  );

  late _MockTaskRepository repository;
  late FakeAnalytics analytics;
  late TaskUseCase useCase;

  setUpAll(() => registerFallbackValue(bread));

  setUp(() {
    repository = _MockTaskRepository();
    analytics = FakeAnalytics();
    useCase = TaskUseCase(
      repository: repository,
      newId: () => 'novo-id',
      now: () => now,
      analytics: analytics,
    );
    when(() => repository.saveTask(any())).thenAnswer((_) async {});
    when(() => repository.archiveTask(any())).thenAnswer((_) async {});
  });

  void stored(Task? task) =>
      when(() => repository.findTask(any())).thenAnswer((_) async => task);

  Task saved() =>
      verify(() => repository.saveTask(captureAny())).captured.single as Task;

  test('criar dá à tarefa um id do aparelho, a hora atual e o título '
      'limpo', () async {
    final task = await useCase.createTask(title: '  Pagar a luz ');

    expect(task.id, 'novo-id');
    expect(task.createdAt, now);
    expect(task.title.value, 'Pagar a luz');
    expect(task.status, TaskStatus.open);
    expect(saved(), same(task));
  });

  test('um título inválido não chega à porta', () async {
    await expectLater(
      useCase.createTask(title: '   '),
      throwsA(isA<EmptyTaskTitleFailure>()),
    );
    stored(bread);
    await expectLater(
      useCase.renameTask('t-1', title: 'x' * 201),
      throwsA(isA<TaskTitleTooLongFailure>()),
    );
    verifyNever(() => repository.saveTask(any()));
  });

  test('concluir, reabrir e renomear gravam a tarefa transformada', () async {
    stored(bread);
    await useCase.completeTask('t-1');
    expect(saved().status, TaskStatus.done);

    stored(bread.complete());
    await useCase.reopenTask('t-1');
    expect(saved().status, TaskStatus.open);

    stored(bread);
    await useCase.renameTask('t-1', title: 'Comprar pão integral');
    expect(saved().title.value, 'Comprar pão integral');
  });

  test('arquivar passa pela operação própria da porta', () async {
    stored(bread);
    await useCase.archiveTask('t-1');

    verify(() => repository.archiveTask('t-1')).called(1);
    verifyNever(() => repository.saveTask(any()));
  });

  test('uma tarefa que não está na lista não pode ser alterada', () async {
    stored(null);
    await expectLater(
      useCase.completeTask('t-9'),
      throwsA(isA<TaskNotFoundFailure>()),
    );

    // Arquivada é o mesmo que fora da lista.
    when(() => repository.findTask('t-1')).thenAnswer(
      (_) async => Task(
        id: 't-1',
        title: bread.title,
        createdAt: now,
        status: TaskStatus.archived,
      ),
    );
    await expectLater(
      useCase.archiveTask('t-1'),
      throwsA(isA<TaskNotFoundFailure>()),
    );
    verifyNever(() => repository.saveTask(any()));
    verifyNever(() => repository.archiveTask(any()));
  });

  test('cada escrita que deu certo registra o seu evento, sem título nem '
      'id', () async {
    final task = await useCase.createTask(title: 'Pagar a luz');
    stored(task);
    await useCase.renameTask(task.id, title: 'Pagar a conta de luz');
    await useCase.completeTask(task.id);
    await useCase.reopenTask(task.id);
    await useCase.archiveTask(task.id);

    expect(analytics.names, [
      'tasks_task_created',
      'tasks_task_renamed',
      'tasks_task_completed',
      'tasks_task_reopened',
      'tasks_task_archived',
    ]);
    for (final (_, parameters) in analytics.events) {
      expect(parameters, isEmpty);
    }
  });

  test('uma escrita que falha não registra evento', () async {
    await expectLater(
      useCase.createTask(title: '   '),
      throwsA(isA<EmptyTaskTitleFailure>()),
    );
    stored(null);
    await expectLater(
      useCase.archiveTask('t-1'),
      throwsA(isA<TaskNotFoundFailure>()),
    );
    when(
      () => repository.saveTask(any()),
    ).thenThrow(const LocalDatabaseError('disco cheio'));
    await expectLater(
      useCase.createTask(title: 'Pagar a luz'),
      throwsA(isA<LocalDatabaseError>()),
    );

    expect(analytics.events, isEmpty);
  });

  test('a preferência das concluídas passa pela porta', () async {
    when(() => repository.showCompletedTasks()).thenAnswer((_) async => false);
    when(
      () => repository.saveShowCompletedTasks(any()),
    ).thenAnswer((_) async {});

    expect(await useCase.showCompletedTasks(), isFalse);
    await useCase.setShowCompletedTasks(true);
    verify(() => repository.saveShowCompletedTasks(true)).called(1);
  });

  test('atualizar pede a lista nova à porta, e a falha chega a quem '
      'pediu', () async {
    when(
      () => repository.refreshActiveTasks(),
    ).thenAnswer((_) async => throw const ApiError(ApiErrorKind.unreachable));

    await expectLater(useCase.refreshTasks(), throwsA(isA<ApiError>()));
    verify(() => repository.refreshActiveTasks()).called(1);
  });

  test('encontrar devolve a tarefa da lista, e null para a arquivada ou a '
      'que não existe', () async {
    stored(bread);
    expect(await useCase.findTask('t-1'), same(bread));

    stored(
      Task(
        id: 't-1',
        title: bread.title,
        createdAt: now,
        status: TaskStatus.archived,
      ),
    );
    expect(await useCase.findTask('t-1'), isNull);

    stored(null);
    expect(await useCase.findTask('t-1'), isNull);
  });

  group('conflitos (capítulo 34)', () {
    TaskConflict conflict(TaskConflictReason reason) =>
        TaskConflict(id: 'c-1', reason: reason, task: bread, createdAt: now);

    setUpAll(() {
      registerFallbackValue(conflict(TaskConflictReason.rejected));
      registerFallbackValue(TaskConflictChoice.discard);
    });

    setUp(() {
      when(
        () => repository.resolveConflict(any(), any()),
      ).thenAnswer((_) async {});
    });

    test('cada motivo tem as suas decisões', () {
      expect(conflict(TaskConflictReason.versionConflict).choices, [
        TaskConflictChoice.keepMine,
        TaskConflictChoice.keepServer,
      ]);
      expect(conflict(TaskConflictReason.rejected).choices, [
        TaskConflictChoice.redo,
        TaskConflictChoice.discard,
      ]);
    });

    test('a decisão que cabe ao motivo chega à porta', () async {
      final versionConflict = conflict(TaskConflictReason.versionConflict);

      await useCase.resolveConflict(
        versionConflict,
        TaskConflictChoice.keepMine,
      );

      verify(
        () => repository.resolveConflict(
          versionConflict,
          TaskConflictChoice.keepMine,
        ),
      ).called(1);
      final (name, parameters) = analytics.events.single;
      expect(name, 'tasks_conflict_resolved');
      expect(parameters, {'reason': 'versionConflict', 'choice': 'keepMine'});
    });

    test('uma decisão que não cabe é defeito de quem chamou, e não chega '
        'à porta', () async {
      await expectLater(
        useCase.resolveConflict(
          conflict(TaskConflictReason.rejected),
          TaskConflictChoice.keepMine,
        ),
        throwsArgumentError,
      );
      await expectLater(
        useCase.resolveConflict(
          conflict(TaskConflictReason.versionConflict),
          TaskConflictChoice.discard,
        ),
        throwsArgumentError,
      );
      verifyNever(() => repository.resolveConflict(any(), any()));
    });

    test('a lista e a versão do servidor passam pela porta', () async {
      final versionConflict = conflict(TaskConflictReason.versionConflict);
      when(
        () => repository.watchConflicts(),
      ).thenAnswer((_) => Stream.value([versionConflict]));
      when(
        () => repository.fetchServerTask('t-1'),
      ).thenAnswer((_) async => bread.complete());

      expect(await useCase.watchConflicts().first, [versionConflict]);
      expect(
        (await useCase.serverVersion(versionConflict))?.status,
        TaskStatus.done,
      );
    });

    test('conflitos são iguais pelo id', () {
      final a = conflict(TaskConflictReason.rejected);
      final b = TaskConflict(
        id: 'c-1',
        reason: TaskConflictReason.versionConflict,
        task: bread.complete(),
        createdAt: now.add(const Duration(hours: 1)),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
