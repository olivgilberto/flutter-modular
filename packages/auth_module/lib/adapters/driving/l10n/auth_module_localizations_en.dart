// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'auth_module_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AuthModuleLocalizationsEn extends AuthModuleLocalizations {
  AuthModuleLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get loginTitle => 'Sign in to your account';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get loginSubmit => 'Sign in';

  @override
  String get loginCreateAccount => 'Create an account';

  @override
  String get loginUnexpectedError =>
      'We couldn\'t sign you in right now. Please try again.';

  @override
  String get checkEmail => 'Check the email you typed.';

  @override
  String get loginInvalidCredentials => 'Incorrect email or password.';

  @override
  String get sessionExpiredMaybeChanges =>
      'Your session has expired, and there may be changes not sent yet. Sign in again to send what is left, or discard it.';

  @override
  String sessionExpiredChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Your session has expired, and there are $count changes not sent yet. Sign in again to send them, or discard them.',
      one:
          'Your session has expired, and there is 1 change not sent yet. Sign in again to send it, or discard it.',
      zero: 'Your session has expired. Sign in again.',
    );
    return '$_temp0';
  }

  @override
  String get discardChanges => 'Discard changes';

  @override
  String get discardChangesTitle => 'Discard changes?';

  @override
  String get discardChangesMessage =>
      'What was done offline will be deleted from this device and cannot be sent later.';

  @override
  String get discard => 'Discard';

  @override
  String get cancel => 'Cancel';

  @override
  String get registerTitle => 'Create your account';

  @override
  String get nameLabel => 'Name';

  @override
  String registerPasswordLabel(int minLength) {
    return 'Password (at least $minLength characters)';
  }

  @override
  String get registerSubmit => 'Create account';

  @override
  String get registerUnexpectedError =>
      'We couldn\'t create the account right now. Please try again.';

  @override
  String registerWeakPassword(int minLength) {
    return 'Choose another password: at least $minLength characters, and not a well-known one.';
  }

  @override
  String get registerEmailTaken =>
      'This email already has an account. Go back and sign in with it.';

  @override
  String get registerCheckData => 'Check your details and try again.';

  @override
  String get logout => 'Sign out';

  @override
  String get logoutTitle => 'Sign out?';

  @override
  String logoutLostChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changes made offline have not been sent yet and will be lost.',
      one: '1 change made offline has not been sent yet and will be lost.',
      zero: 'No change made offline is waiting to be sent.',
    );
    return '$_temp0';
  }

  @override
  String get logoutCheckFailed =>
      'We couldn\'t check for changes not sent yet. If there are any, they will be lost.';

  @override
  String get logoutConfirm => 'Sign out anyway';
}
