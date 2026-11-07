import 'package:go_router/go_router.dart';

import '../pages/task_conflicts_page.dart';
import '../pages/task_edit_page.dart';
import '../pages/task_list_page.dart';

/// Os nomes e caminhos das rotas do módulo, no formato `[módulo].[tela]` e
/// `/[módulo]/[tela]`, como os do auth_module (capítulo 22). Fazem parte do
/// contrato público do módulo (docs/modules/tasks_module.md).
abstract final class TaskRoutes {
  static const prefix = '/tasks';
  static const list = 'tasks.list';
  static const listPath = prefix;
  static const edit = 'tasks.edit';
  static const editPath = '$prefix/edit/:taskId';
  static const conflicts = 'tasks.conflicts';
  static const conflictsPath = '$prefix/conflicts';
}

/// A lista que o host espalha no `GoRouter`. O módulo nunca registra rotas
/// num roteador global, e a lista não pode ser alterada por quem a recebe.
final List<RouteBase> tasksModuleRoutes = List.unmodifiable([
  GoRoute(
    name: TaskRoutes.list,
    path: TaskRoutes.listPath,
    builder: (context, state) => const TaskListPage(),
  ),
  GoRoute(
    name: TaskRoutes.edit,
    path: TaskRoutes.editPath,
    builder: (context, state) =>
        TaskEditPage(taskId: state.pathParameters['taskId']!),
  ),
  GoRoute(
    name: TaskRoutes.conflicts,
    path: TaskRoutes.conflictsPath,
    builder: (context, state) => const TaskConflictsPage(),
  ),
]);
