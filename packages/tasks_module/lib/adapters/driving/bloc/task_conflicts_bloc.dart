import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../application/use_cases/task_use_case.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/task_conflict.dart';

part 'task_conflicts_event.dart';
part 'task_conflicts_state.dart';

/// O ViewModel da tela de conflitos (capítulo 34): a lista do que o
/// servidor não aceitou, a versão do servidor de cada um, buscada quando
/// a tela abre, e a decisão do usuário.
///
/// Não é `final`: os testes da View o simulam com `implements`.
class TaskConflictsBloc extends Bloc<TaskConflictsEvent, TaskConflictsState> {
  TaskConflictsBloc({required TaskUseCase tasks})
    : _tasks = tasks,
      super(const TaskConflictsState()) {
    on<TaskConflictsStarted>(_onStarted, transformer: restartable());
    on<ServerVersionRequested>(_onServerVersionRequested);
    // Uma decisão por vez.
    on<TaskConflictResolved>(_onResolved, transformer: droppable());
  }

  final TaskUseCase _tasks;

  Future<void> _onStarted(
    TaskConflictsStarted event,
    Emitter<TaskConflictsState> emit,
  ) => emit.forEach<List<TaskConflict>>(
    _tasks.watchConflicts(),
    onData: (conflicts) {
      for (final conflict in conflicts) {
        if (!state.servers.containsKey(conflict.id)) {
          add(ServerVersionRequested(conflict));
        }
      }
      return state.copyWith(loading: false, conflicts: conflicts);
    },
    onError: (error, stackTrace) => error is LocalDatabaseError
        ? state.copyWith(
            loading: false,
            notice: TaskConflictsNotice.unavailable,
          )
        : Error.throwWithStackTrace(error, stackTrace),
  );

  Future<void> _onServerVersionRequested(
    ServerVersionRequested event,
    Emitter<TaskConflictsState> emit,
  ) async {
    final id = event.conflict.id;
    emit(state.withServer(id, const ServerVersionLoading()));
    try {
      final server = await _tasks.serverVersion(event.conflict);
      emit(state.withServer(id, ServerVersionFound(server)));
    } on ApiError {
      emit(state.withServer(id, const ServerVersionUnavailable()));
    }
  }

  Future<void> _onResolved(
    TaskConflictResolved event,
    Emitter<TaskConflictsState> emit,
  ) async {
    emit(state.copyWith(resolving: event.conflict.id));
    try {
      await _tasks.resolveConflict(event.conflict, event.choice);
      emit(
        state.copyWith(
          // "Refazer" leva à tela da tarefa, no estado que ela tem agora.
          redoTaskId: event.choice == TaskConflictChoice.redo
              ? event.conflict.task.id
              : null,
        ),
      );
    } on ApiError {
      emit(state.copyWith(notice: TaskConflictsNotice.offline));
    } on LocalDatabaseError {
      emit(state.copyWith(notice: TaskConflictsNotice.unavailable));
    }
  }
}
