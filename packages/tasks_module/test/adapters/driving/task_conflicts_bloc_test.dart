import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tasks_module/adapters/driving/bloc/task_conflicts_bloc.dart';
import 'package:tasks_module/domain/entities/task_conflict.dart';

import 'driving_mocks.dart';

void main() {
  late MockTaskUseCase tasks;
  late StreamController<List<TaskConflict>> conflicts;
  final mine = conflictOf(bread.complete());
  final refused = conflictOf(
    light,
    id: 'c-2',
    reason: TaskConflictReason.rejected,
  );

  setUpAll(() {
    registerFallbackValue(mine);
    registerFallbackValue(TaskConflictChoice.discard);
  });

  setUp(() {
    tasks = MockTaskUseCase();
    conflicts = StreamController();
    when(() => tasks.watchConflicts()).thenAnswer((_) => conflicts.stream);
    when(() => tasks.serverVersion(any())).thenAnswer((_) async => bread);
    when(() => tasks.resolveConflict(any(), any())).thenAnswer((_) async {});
  });
  // Sem await: um StreamController que ninguém escutou nunca termina de
  // fechar.
  tearDown(() => unawaited(conflicts.close()));

  Future<TaskConflictsBloc> opened(List<TaskConflict> initial) async {
    final bloc = TaskConflictsBloc(tasks: tasks)
      ..add(const TaskConflictsStarted());
    addTearDown(bloc.close);
    conflicts.add(initial);
    await pumpEventQueue();
    return bloc;
  }

  test('começa carregando', () {
    final bloc = TaskConflictsBloc(tasks: tasks);
    addTearDown(bloc.close);
    expect(bloc.state.loading, isTrue);
  });

  test('a lista chega, e a versão do servidor de cada conflito é buscada '
      'uma vez', () async {
    final bloc = await opened([mine, refused]);
    conflicts.add([mine, refused]);
    await pumpEventQueue();

    expect(bloc.state.loading, isFalse);
    expect(bloc.state.conflicts, [mine, refused]);
    final server = bloc.state.servers['c-1'];
    expect(server, isA<ServerVersionFound>());
    expect((server! as ServerVersionFound).task, bread);
    expect(bloc.state.servers['c-2'], isA<ServerVersionFound>());
    verify(() => tasks.serverVersion(mine)).called(1);
    verify(() => tasks.serverVersion(refused)).called(1);
  });

  test('sem rede, a versão do servidor fica indisponível, e pedir de novo '
      'busca outra vez', () async {
    when(
      () => tasks.serverVersion(any()),
    ).thenThrow(const ApiError(ApiErrorKind.unreachable));
    final bloc = await opened([mine]);
    expect(bloc.state.servers['c-1'], isA<ServerVersionUnavailable>());

    when(() => tasks.serverVersion(any())).thenAnswer((_) async => null);
    bloc.add(ServerVersionRequested(mine));
    await pumpEventQueue();

    final server = bloc.state.servers['c-1'];
    expect(server, isA<ServerVersionFound>());
    expect((server! as ServerVersionFound).task, isNull);
  });

  test('o banco travado mostra o aviso e para de carregar', () async {
    final bloc = TaskConflictsBloc(tasks: tasks)
      ..add(const TaskConflictsStarted());
    addTearDown(bloc.close);
    conflicts.addError(const LocalDatabaseError('travado'));
    await pumpEventQueue();

    expect(bloc.state.loading, isFalse);
    expect(bloc.state.notice, TaskConflictsNotice.unavailable);
  });

  test('a decisão chega ao caso de uso, e o conflito sai pela lista', () async {
    final bloc = await opened([mine]);

    bloc.add(TaskConflictResolved(mine, TaskConflictChoice.keepMine));
    await pumpEventQueue();
    conflicts.add([]);
    await pumpEventQueue();

    verify(
      () => tasks.resolveConflict(mine, TaskConflictChoice.keepMine),
    ).called(1);
    expect(bloc.state.conflicts, isEmpty);
    expect(bloc.state.resolving, isNull);
    expect(bloc.state.redoTaskId, isNull);
  });

  test('durante a decisão, o conflito fica marcado, e outra é '
      'ignorada', () async {
    final applying = Completer<void>();
    when(
      () => tasks.resolveConflict(any(), any()),
    ).thenAnswer((_) => applying.future);
    final bloc = await opened([mine]);

    bloc
      ..add(TaskConflictResolved(mine, TaskConflictChoice.keepMine))
      ..add(TaskConflictResolved(mine, TaskConflictChoice.keepServer));
    await pumpEventQueue();
    expect(bloc.state.resolving, 'c-1');

    applying.complete();
    await pumpEventQueue();
    verify(() => tasks.resolveConflict(any(), any())).called(1);
  });

  test('refazer leva à tela da tarefa', () async {
    final bloc = await opened([refused]);

    bloc.add(TaskConflictResolved(refused, TaskConflictChoice.redo));
    await pumpEventQueue();

    expect(bloc.state.redoTaskId, 't-2');
  });

  for (final (thrown, notice) in [
    (const ApiError(ApiErrorKind.unreachable), TaskConflictsNotice.offline),
    (const LocalDatabaseError('travado'), TaskConflictsNotice.unavailable),
  ]) {
    test('${thrown.runtimeType} vira o aviso ${notice.name}, e o conflito '
        'fica', () async {
      when(() => tasks.resolveConflict(any(), any())).thenThrow(thrown);
      final bloc = await opened([mine]);

      bloc.add(TaskConflictResolved(mine, TaskConflictChoice.keepMine));
      await pumpEventQueue();

      expect(bloc.state.notice, notice);
      expect(bloc.state.resolving, isNull);
      expect(bloc.state.conflicts, [mine]);
    });
  }

  test('cada cópia do estado esquece a navegação e o aviso', () {
    const state = TaskConflictsState(
      redoTaskId: 't-1',
      notice: TaskConflictsNotice.offline,
      resolving: 'c-1',
    );
    final copy = state.withServer('c-1', const ServerVersionLoading());
    expect(copy.redoTaskId, isNull);
    expect(copy.notice, isNull);
    expect(copy.resolving, isNull);
    expect(copy.servers['c-1'], isA<ServerVersionLoading>());
  });
}
