import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tasks_module/adapters/driving/bloc/task_conflicts_bloc.dart';
import 'package:tasks_module/adapters/driving/bloc/task_edit_bloc.dart';
import 'package:tasks_module/adapters/driving/bloc/task_list_bloc.dart';
import 'package:tasks_module/application/use_cases/task_use_case.dart';
import 'package:tasks_module/domain/entities/task.dart';
import 'package:tasks_module/domain/entities/task_conflict.dart';
import 'package:tasks_module/domain/value_objects/task_title.dart';

/// Possível porque o `TaskUseCase` não é `final`.
final class MockTaskUseCase extends Mock implements TaskUseCase {}

/// Possíveis porque os Blocs não são `final`.
final class MockTaskListBloc extends MockBloc<TaskListEvent, TaskListState>
    implements TaskListBloc {}

final class MockTaskEditBloc extends MockBloc<TaskEditEvent, TaskEditState>
    implements TaskEditBloc {}

final class MockTaskConflictsBloc
    extends MockBloc<TaskConflictsEvent, TaskConflictsState>
    implements TaskConflictsBloc {}

Task task(String id, String title, {TaskStatus status = TaskStatus.open}) =>
    Task(
      id: id,
      title: TaskTitle.parse(title),
      createdAt: DateTime.utc(2026, 10, 28, 9),
      status: status,
    );

final bread = task('t-1', 'Comprar pão');
final light = task('t-2', 'Pagar a luz', status: TaskStatus.done);

TaskConflict conflictOf(
  Task task, {
  String id = 'c-1',
  TaskConflictReason reason = TaskConflictReason.versionConflict,
}) => TaskConflict(
  id: id,
  reason: reason,
  task: task,
  createdAt: DateTime.utc(2026, 10, 28, 10),
);
