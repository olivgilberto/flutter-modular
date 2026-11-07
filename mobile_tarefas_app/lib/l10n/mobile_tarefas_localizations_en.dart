// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'mobile_tarefas_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class MobileTarefasLocalizationsEn extends MobileTarefasLocalizations {
  MobileTarefasLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tasks';

  @override
  String get connectivityOffline =>
      'No connection. What you do is kept and sent when the connection is back.';

  @override
  String get connectivityNoInternet =>
      'No access to the server. What you do is kept and sent as soon as it answers.';

  @override
  String get deviceIntegrityWarning =>
      'This device seems to be rooted or jailbroken. The app keeps working, but the data stored on it is less protected.';

  @override
  String get deviceIntegrityDismiss => 'Got it';
}
