import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/task.dart';
import '../../../domain/entities/task_conflict.dart';
import '../bloc/task_conflicts_bloc.dart';
import '../l10n/tasks_module_localizations.dart';
import '../routes/tasks_module_routes.dart';

/// O que o servidor não aceitou, com as duas versões lado a lado e as
/// decisões que cabem a cada caso (capítulo 34). Nada é decidido sem o
/// usuário.
final class TaskConflictsView extends StatelessWidget {
  const TaskConflictsView({super.key});

  void _onState(BuildContext context, TaskConflictsState state) {
    if (state.redoTaskId case final taskId?) {
      context.pushReplacementNamed(
        TaskRoutes.edit,
        pathParameters: {'taskId': taskId},
      );
      return;
    }
    final notice = state.notice;
    if (notice == null) return;
    final l10n = TasksModuleLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(switch (notice) {
            TaskConflictsNotice.offline => l10n.conflictsOffline,
            TaskConflictsNotice.unavailable => l10n.unexpectedError,
          }),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TaskConflictsBloc>().state;
    final l10n = TasksModuleLocalizations.of(context);

    return BlocListener<TaskConflictsBloc, TaskConflictsState>(
      listenWhen: (_, current) =>
          current.notice != null || current.redoTaskId != null,
      listener: _onState,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.conflictsTitle)),
        body: SafeArea(
          child: state.loading
              ? const Center(child: CircularProgressIndicator())
              : state.conflicts.isEmpty
              ? AppEmptyState(
                  icon: Icons.task_alt_outlined,
                  title: l10n.noConflicts,
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    for (final conflict in state.conflicts)
                      _ConflictCard(
                        conflict: conflict,
                        server:
                            state.servers[conflict.id] ??
                            const ServerVersionLoading(),
                        busy: state.resolving == conflict.id,
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

final class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.server,
    required this.busy,
  });

  final TaskConflict conflict;
  final ServerVersion server;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = TasksModuleLocalizations.of(context);
    final serverTask = switch (server) {
      ServerVersionFound(:final task) => task,
      _ => null,
    };
    final serverKnown = server is ServerVersionFound;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.sm,
          children: [
            Text(switch (conflict.reason) {
              TaskConflictReason.versionConflict =>
                l10n.conflictChangedElsewhere,
              TaskConflictReason.rejected => l10n.conflictRejected,
            }, style: theme.textTheme.titleMedium),
            Text(l10n.onDevice(_describe(l10n, conflict.task))),
            switch (server) {
              ServerVersionLoading() => Text(l10n.fetchingServer),
              ServerVersionFound(task: null) => Text(l10n.serverGone),
              ServerVersionFound(:final task?) => Text(
                l10n.onServer(_describe(l10n, task)),
              ),
              ServerVersionUnavailable() => Row(
                children: [
                  Expanded(child: Text(l10n.serverUnavailable)),
                  TextButton(
                    onPressed: () => context.read<TaskConflictsBloc>().add(
                      ServerVersionRequested(conflict),
                    ),
                    child: Text(l10n.tryAgain),
                  ),
                ],
              ),
            },
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              children: [
                for (final choice in conflict.choices)
                  TextButton(
                    onPressed:
                        busy || !_allowed(choice, serverKnown, serverTask)
                        ? null
                        : () => _choose(context, choice),
                    child: Text(_label(l10n, choice)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Comparar e refazer pedem a versão do servidor; descartar, não.
  /// Refazer pede que a tarefa ainda exista lá.
  static bool _allowed(TaskConflictChoice choice, bool known, Task? task) =>
      switch (choice) {
        TaskConflictChoice.discard => true,
        TaskConflictChoice.redo => known && task != null,
        TaskConflictChoice.keepMine || TaskConflictChoice.keepServer => known,
      };

  Future<void> _choose(BuildContext context, TaskConflictChoice choice) async {
    final bloc = context.read<TaskConflictsBloc>();
    if (choice == TaskConflictChoice.discard) {
      final l10n = TasksModuleLocalizations.of(context);
      final confirmed = await showAppConfirmDialog(
        context,
        title: l10n.discardTitle,
        message: l10n.discardMessage,
        confirmLabel: l10n.discard,
        cancelLabel: l10n.cancel,
      );
      if (!confirmed) return;
    }
    bloc.add(TaskConflictResolved(conflict, choice));
  }

  /// O título e a situação. A situação vai pelo nome do valor do enum, e
  /// o `select` do ARB escolhe a palavra de cada idioma.
  static String _describe(TasksModuleLocalizations l10n, Task task) =>
      l10n.taskSummary(task.title.value, task.status.name);

  static String _label(
    TasksModuleLocalizations l10n,
    TaskConflictChoice choice,
  ) => switch (choice) {
    TaskConflictChoice.keepMine => l10n.keepMine,
    TaskConflictChoice.keepServer => l10n.keepServer,
    TaskConflictChoice.redo => l10n.redo,
    TaskConflictChoice.discard => l10n.discard,
  };
}
