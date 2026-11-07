import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/task.dart';
import '../bloc/task_list_bloc.dart';
import '../l10n/tasks_module_localizations.dart';
import '../routes/tasks_module_routes.dart';

/// A lista de tarefas. Não sabe de onde o Bloc vem nem se há rede: tudo o
/// que ela pede é guardado no aparelho na hora (capítulo 33). Os textos vêm
/// dos arquivos de tradução do módulo (capítulo 37).
final class TaskListView extends StatefulWidget {
  const TaskListView({super.key});

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

final class _TaskListViewState extends State<TaskListView> {
  final _title = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _create() => context.read<TaskListBloc>().add(TaskCreated(_title.text));

  /// O indicador do gesto gira até a atualização terminar, com ou sem rede.
  Future<void> _refresh() async {
    final bloc = context.read<TaskListBloc>()..add(const TaskListRefreshed());
    await bloc.stream.firstWhere((state) => !state.refreshing);
  }

  void _onNotice(BuildContext context, TaskListState state) {
    final notice = state.notice;
    if (notice == null) return;
    if (notice == TaskListNotice.created) {
      _title.clear();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _messageFor(TasksModuleLocalizations.of(context), notice),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TaskListBloc>().state;
    final margin = AppMargins.of(AppBreakpoints.widthClassOf(context));
    final l10n = TasksModuleLocalizations.of(context);

    return BlocListener<TaskListBloc, TaskListState>(
      listenWhen: (_, current) => current.notice != null,
      listener: _onNotice,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.tasksTitle),
          actions: [
            IconButton(
              tooltip: state.showCompleted
                  ? l10n.hideCompleted
                  : l10n.showCompleted,
              icon: Icon(
                state.showCompleted
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () => context.read<TaskListBloc>().add(
                const ShowCompletedToggled(),
              ),
            ),
          ],
        ),
        body: SafeArea(
          // Tudo rola junto: o aviso de conflitos, o campo e a lista
          // (capítulo 39). Com a fonte do sistema grande, o que fica acima
          // da lista cresce, e uma lista presa ao espaço que sobrasse
          // ficaria sem espaço nenhum, com a tela transbordando.
          child: RefreshIndicator(
            onRefresh: _refresh,
            notificationPredicate: (notification) =>
                notification.depth == 0 && state.status == TaskListStatus.ready,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (state.conflicts > 0)
                  SliverToBoxAdapter(
                    child: _ConflictsNotice(
                      count: state.conflicts,
                      onOpen: () => context.pushNamed(TaskRoutes.conflicts),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      margin,
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _title,
                            label: l10n.newTaskLabel,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _create(),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.add,
                          icon: const Icon(Icons.add),
                          onPressed: _create,
                        ),
                      ],
                    ),
                  ),
                ),
                switch (state.status) {
                  TaskListStatus.loading => const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  TaskListStatus.failure => SliverFillRemaining(
                    hasScrollBody: false,
                    child: _LoadFailure(
                      onRetry: () => context.read<TaskListBloc>().add(
                        const TaskListStarted(),
                      ),
                    ),
                  ),
                  TaskListStatus.ready => _TaskList(tasks: state.visibleTasks),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _messageFor(
    TasksModuleLocalizations l10n,
    TaskListNotice notice,
  ) => switch (notice) {
    TaskListNotice.emptyTitle => l10n.emptyTitle,
    TaskListNotice.titleTooLong => l10n.titleTooLong,
    TaskListNotice.notFound => l10n.taskGone,
    TaskListNotice.refreshFailed => l10n.refreshFailed,
    TaskListNotice.unavailable => l10n.unexpectedError,
    TaskListNotice.created => '',
  };
}

/// As tarefas, como um sliver da rolagem da tela.
final class _TaskList extends StatelessWidget {
  const _TaskList({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final l10n = TasksModuleLocalizations.of(context);
    if (tasks.isEmpty) {
      return SliverToBoxAdapter(
        child: AppEmptyState(
          icon: Icons.checklist_outlined,
          title: l10n.emptyListTitle,
          message: l10n.emptyListMessage,
        ),
      );
    }
    return SliverList.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return CheckboxListTile(
          value: task.isDone,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (_) => context.read<TaskListBloc>().add(TaskToggled(task)),
          title: Text(
            task.title.value,
            style: task.isDone
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
          secondary: IconButton(
            tooltip: l10n.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.pushNamed(
              TaskRoutes.edit,
              pathParameters: {'taskId': task.id},
            ),
          ),
        );
      },
    );
  }
}

/// O aviso das alterações que esperam decisão. Não bloqueia nada: a lista
/// continua inteira abaixo dele. O texto ocupa a largura toda e o botão vai
/// abaixo dele (capítulo 39): ao lado, como no ListTile de antes, a fonte
/// grande fazia o botão tomar a linha inteira e espremia o texto numa
/// coluna estreita.
final class _ConflictsNotice extends StatelessWidget {
  const _ConflictsNotice({required this.count, required this.onOpen});

  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = TasksModuleLocalizations.of(context);
    return Material(
      color: colors.tertiaryContainer,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.sm,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.sync_problem_outlined,
                    color: colors.onTertiaryContainer,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      l10n.conflictsNotice(count),
                      style: TextStyle(color: colors.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(onPressed: onOpen, child: Text(l10n.resolve)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = TasksModuleLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: l10n.loadFailedTitle,
          message: l10n.loadFailedMessage,
        ),
        AppTextButton(label: l10n.tryAgain, onPressed: onRetry),
      ],
    );
  }
}
