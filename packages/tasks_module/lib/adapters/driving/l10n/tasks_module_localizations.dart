import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'tasks_module_localizations_en.dart';
import 'tasks_module_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of TasksModuleLocalizations
/// returned by `TasksModuleLocalizations.of(context)`.
///
/// Applications need to include `TasksModuleLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/tasks_module_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: TasksModuleLocalizations.localizationsDelegates,
///   supportedLocales: TasksModuleLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the TasksModuleLocalizations.supportedLocales
/// property.
abstract class TasksModuleLocalizations {
  TasksModuleLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static TasksModuleLocalizations of(BuildContext context) {
    return Localizations.of<TasksModuleLocalizations>(
      context,
      TasksModuleLocalizations,
    )!;
  }

  static const LocalizationsDelegate<TasksModuleLocalizations> delegate =
      _TasksModuleLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// Title of the task list.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasksTitle;

  /// Tooltip of the button that hides completed tasks.
  ///
  /// In en, this message translates to:
  /// **'Hide completed'**
  String get hideCompleted;

  /// Tooltip of the button that shows completed tasks.
  ///
  /// In en, this message translates to:
  /// **'Show completed'**
  String get showCompleted;

  /// Label of the field that creates a task.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get newTaskLabel;

  /// Tooltip of the button that creates a task.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Shown when a task is saved without a title.
  ///
  /// In en, this message translates to:
  /// **'Write a title for the task.'**
  String get emptyTitle;

  /// Shown when a task title is too long.
  ///
  /// In en, this message translates to:
  /// **'The title is over the maximum length.'**
  String get titleTooLong;

  /// Shown when the task was removed while the user was looking at it.
  ///
  /// In en, this message translates to:
  /// **'This task is no longer on the list.'**
  String get taskGone;

  /// Title of the screen of a task that was removed while it was open.
  ///
  /// In en, this message translates to:
  /// **'This task is no longer on the list'**
  String get taskGoneTitle;

  /// Shown when pull-to-refresh fails; the list stored on the device stays on screen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh right now. The list on this device is still here.'**
  String get refreshFailed;

  /// Shown when an action fails for a reason the user cannot fix.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get unexpectedError;

  /// Title shown when the list has no tasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks here'**
  String get emptyListTitle;

  /// Message shown when the list has no tasks.
  ///
  /// In en, this message translates to:
  /// **'Write the first one in the field above.'**
  String get emptyListMessage;

  /// Tooltip of the button that opens a task.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Notice above the list when the server did not accept some changes. Has a case for zero: in Portuguese, the plural category 'one' covers 0 and 1.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No change needs your decision} =1{1 change needs your decision} other{{count} changes need your decision}}'**
  String conflictsNotice(int count);

  /// Button of the notice that opens the screen of changes not accepted.
  ///
  /// In en, this message translates to:
  /// **'Resolve'**
  String get resolve;

  /// Title shown when the first list could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the tasks'**
  String get loadFailedTitle;

  /// Message shown when the first list could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'The first list comes from the server. Check the connection.'**
  String get loadFailedMessage;

  /// Button that repeats an action that failed.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// Title of the screen of one task.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get taskTitle;

  /// Label of the task title field.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get taskTitleLabel;

  /// Button that saves the task.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Button that archives the task, and confirm button of its dialog.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// Title of the dialog that confirms archiving a task.
  ///
  /// In en, this message translates to:
  /// **'Archive task?'**
  String get archiveTitle;

  /// Body of the dialog that confirms archiving a task.
  ///
  /// In en, this message translates to:
  /// **'It leaves the list. On this device, there is no way to undo it.'**
  String get archiveMessage;

  /// Cancel button of the module's dialogs.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Title of the screen of changes the server did not accept.
  ///
  /// In en, this message translates to:
  /// **'Changes not accepted'**
  String get conflictsTitle;

  /// Shown when there are no changes waiting for a decision.
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting for your decision'**
  String get noConflicts;

  /// Shown when a decision needs the server and there is no connection.
  ///
  /// In en, this message translates to:
  /// **'No connection to the server. Try again when it is back.'**
  String get conflictsOffline;

  /// Heading of a change that conflicts with a newer version on the server.
  ///
  /// In en, this message translates to:
  /// **'This task changed somewhere else'**
  String get conflictChangedElsewhere;

  /// Heading of a change the server refused.
  ///
  /// In en, this message translates to:
  /// **'The server rejected this change'**
  String get conflictRejected;

  /// A task as shown when comparing versions: the title and the status. The status is the name of the TaskStatus value.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\", {status, select, open{open} done{done} archived{archived} other{{status}}}'**
  String taskSummary(String title, String status);

  /// The version of a task on the device; task is the task summary.
  ///
  /// In en, this message translates to:
  /// **'On this device: {task}'**
  String onDevice(String task);

  /// The version of a task on the server; task is the task summary.
  ///
  /// In en, this message translates to:
  /// **'On the server: {task}'**
  String onServer(String task);

  /// Shown while the server version of a task is loading.
  ///
  /// In en, this message translates to:
  /// **'Fetching the server version…'**
  String get fetchingServer;

  /// Shown when the task was deleted on the server.
  ///
  /// In en, this message translates to:
  /// **'On the server: the task no longer exists.'**
  String get serverGone;

  /// Shown when the server version could not be fetched.
  ///
  /// In en, this message translates to:
  /// **'No connection to fetch the server version.'**
  String get serverUnavailable;

  /// Decision: send the device version over the server one.
  ///
  /// In en, this message translates to:
  /// **'Keep mine'**
  String get keepMine;

  /// Decision: drop the device version and keep the server one.
  ///
  /// In en, this message translates to:
  /// **'Keep the server\'s'**
  String get keepServer;

  /// Decision: open the task to make the change again.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// Decision: delete the change from the device; also the confirm button of its dialog.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// Title of the dialog that confirms discarding a change.
  ///
  /// In en, this message translates to:
  /// **'Discard the change?'**
  String get discardTitle;

  /// Body of the dialog that confirms discarding a change.
  ///
  /// In en, this message translates to:
  /// **'What you did to this task will be deleted from this device, and the server version comes back at the next refresh.'**
  String get discardMessage;
}

class _TasksModuleLocalizationsDelegate
    extends LocalizationsDelegate<TasksModuleLocalizations> {
  const _TasksModuleLocalizationsDelegate();

  @override
  Future<TasksModuleLocalizations> load(Locale locale) {
    return SynchronousFuture<TasksModuleLocalizations>(
      lookupTasksModuleLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_TasksModuleLocalizationsDelegate old) => false;
}

TasksModuleLocalizations lookupTasksModuleLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return TasksModuleLocalizationsEn();
    case 'pt':
      return TasksModuleLocalizationsPt();
  }

  throw FlutterError(
    'TasksModuleLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
