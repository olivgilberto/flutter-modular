import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../bloc/task_list_bloc.dart';
import '../views/task_list_view.dart';

/// O ponto de entrada da rota `tasks.list`: obtém um Bloc novo e o entrega
/// à View. As Pages são os únicos pontos do lado driving que consultam o
/// `get_it`.
final class TaskListPage extends StatelessWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<TaskListBloc>(
    create: (_) => GetIt.instance<TaskListBloc>()..add(const TaskListStarted()),
    child: const TaskListView(),
  );
}
