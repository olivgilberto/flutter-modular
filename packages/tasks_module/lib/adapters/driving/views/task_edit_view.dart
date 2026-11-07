import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/task_failure.dart';
import '../bloc/task_edit_bloc.dart';
import '../l10n/tasks_module_localizations.dart';

/// A tela de uma tarefa: renomear e arquivar. Fecha assim que a mudança
/// está guardada no aparelho; o envio acontece por trás.
final class TaskEditView extends StatefulWidget {
  const TaskEditView({super.key});

  @override
  State<TaskEditView> createState() => _TaskEditViewState();
}

final class _TaskEditViewState extends State<TaskEditView> {
  final _title = TextEditingController();
  var _filled = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _onState(BuildContext context, TaskEditState state) {
    switch (state) {
      case TaskEditReady(:final task) when !_filled:
        _filled = true;
        _title.text = task.title.value;
      case TaskEditDone():
        if (context.canPop()) context.pop();
      default:
        break;
    }
  }

  Future<void> _confirmArchive() async {
    final bloc = context.read<TaskEditBloc>();
    final l10n = TasksModuleLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.archiveTitle,
      message: l10n.archiveMessage,
      confirmLabel: l10n.archive,
      cancelLabel: l10n.cancel,
    );
    if (confirmed) bloc.add(const TaskEditArchived());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TaskEditBloc>().state;
    final busy = state is TaskEditSaving || state is TaskEditDone;
    final l10n = TasksModuleLocalizations.of(context);

    return BlocListener<TaskEditBloc, TaskEditState>(
      listener: _onState,
      child: switch (state) {
        TaskEditLoading() => Scaffold(
          appBar: AppBar(title: Text(l10n.taskTitle)),
          body: const Center(child: CircularProgressIndicator()),
        ),
        TaskEditNotFound() => Scaffold(
          appBar: AppBar(title: Text(l10n.taskTitle)),
          body: AppEmptyState(
            icon: Icons.search_off_outlined,
            title: l10n.taskGoneTitle,
          ),
        ),
        _ => AppForm(
          title: l10n.taskTitle,
          children: [
            AppTextField(
              controller: _title,
              label: l10n.taskTitleLabel,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => context.read<TaskEditBloc>().add(
                TaskEditSubmitted(_title.text),
              ),
            ),
            if (state case TaskEditReady(:final failure?))
              AppInlineError(message: _messageFor(l10n, failure)),
            if (state case TaskEditReady(unavailable: true))
              AppInlineError(message: l10n.unexpectedError),
            AppPrimaryButton(
              label: l10n.save,
              loading: busy,
              onPressed: () => context.read<TaskEditBloc>().add(
                TaskEditSubmitted(_title.text),
              ),
            ),
            AppTextButton(
              label: l10n.archive,
              onPressed: busy ? null : _confirmArchive,
            ),
          ],
        ),
      },
    );
  }

  static String _messageFor(
    TasksModuleLocalizations l10n,
    TaskFailure failure,
  ) => switch (failure) {
    EmptyTaskTitleFailure() => l10n.emptyTitle,
    TaskTitleTooLongFailure() => l10n.titleTooLong,
    TaskNotFoundFailure() => l10n.taskGone,
  };
}
