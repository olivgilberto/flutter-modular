import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../bloc/task_conflicts_bloc.dart';
import '../views/task_conflicts_view.dart';

/// O ponto de entrada da rota `tasks.conflicts` (capítulo 34).
final class TaskConflictsPage extends StatelessWidget {
  const TaskConflictsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<TaskConflictsBloc>(
    create: (_) =>
        GetIt.instance<TaskConflictsBloc>()..add(const TaskConflictsStarted()),
    child: const TaskConflictsView(),
  );
}
