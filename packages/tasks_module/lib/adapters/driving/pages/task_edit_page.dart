import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../bloc/task_edit_bloc.dart';
import '../views/task_edit_view.dart';

/// O ponto de entrada da rota `tasks.edit`.
final class TaskEditPage extends StatelessWidget {
  const TaskEditPage({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context) => BlocProvider<TaskEditBloc>(
    create: (_) => GetIt.instance<TaskEditBloc>()..add(TaskEditStarted(taskId)),
    child: const TaskEditView(),
  );
}
