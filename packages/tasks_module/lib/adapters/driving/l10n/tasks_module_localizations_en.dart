// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'tasks_module_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class TasksModuleLocalizationsEn extends TasksModuleLocalizations {
  TasksModuleLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tasksTitle => 'Tasks';

  @override
  String get hideCompleted => 'Hide completed';

  @override
  String get showCompleted => 'Show completed';

  @override
  String get newTaskLabel => 'New task';

  @override
  String get add => 'Add';

  @override
  String get emptyTitle => 'Write a title for the task.';

  @override
  String get titleTooLong => 'The title is over the maximum length.';

  @override
  String get taskGone => 'This task is no longer on the list.';

  @override
  String get taskGoneTitle => 'This task is no longer on the list';

  @override
  String get refreshFailed =>
      'Couldn\'t refresh right now. The list on this device is still here.';

  @override
  String get unexpectedError => 'Something went wrong. Please try again.';

  @override
  String get emptyListTitle => 'No tasks here';

  @override
  String get emptyListMessage => 'Write the first one in the field above.';

  @override
  String get edit => 'Edit';

  @override
  String conflictsNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes need your decision',
      one: '1 change needs your decision',
      zero: 'No change needs your decision',
    );
    return '$_temp0';
  }

  @override
  String get resolve => 'Resolve';

  @override
  String get loadFailedTitle => 'Couldn\'t load the tasks';

  @override
  String get loadFailedMessage =>
      'The first list comes from the server. Check the connection.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get taskTitle => 'Task';

  @override
  String get taskTitleLabel => 'Title';

  @override
  String get save => 'Save';

  @override
  String get archive => 'Archive';

  @override
  String get archiveTitle => 'Archive task?';

  @override
  String get archiveMessage =>
      'It leaves the list. On this device, there is no way to undo it.';

  @override
  String get cancel => 'Cancel';

  @override
  String get conflictsTitle => 'Changes not accepted';

  @override
  String get noConflicts => 'Nothing waiting for your decision';

  @override
  String get conflictsOffline =>
      'No connection to the server. Try again when it is back.';

  @override
  String get conflictChangedElsewhere => 'This task changed somewhere else';

  @override
  String get conflictRejected => 'The server rejected this change';

  @override
  String taskSummary(String title, String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'open': 'open',
      'done': 'done',
      'archived': 'archived',
      'other': '$status',
    });
    return '\"$title\", $_temp0';
  }

  @override
  String onDevice(String task) {
    return 'On this device: $task';
  }

  @override
  String onServer(String task) {
    return 'On the server: $task';
  }

  @override
  String get fetchingServer => 'Fetching the server version…';

  @override
  String get serverGone => 'On the server: the task no longer exists.';

  @override
  String get serverUnavailable => 'No connection to fetch the server version.';

  @override
  String get keepMine => 'Keep mine';

  @override
  String get keepServer => 'Keep the server\'s';

  @override
  String get redo => 'Redo';

  @override
  String get discard => 'Discard';

  @override
  String get discardTitle => 'Discard the change?';

  @override
  String get discardMessage =>
      'What you did to this task will be deleted from this device, and the server version comes back at the next refresh.';
}
