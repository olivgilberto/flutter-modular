import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'auth_module_localizations_en.dart';
import 'auth_module_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AuthModuleLocalizations
/// returned by `AuthModuleLocalizations.of(context)`.
///
/// Applications need to include `AuthModuleLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/auth_module_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AuthModuleLocalizations.localizationsDelegates,
///   supportedLocales: AuthModuleLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AuthModuleLocalizations.supportedLocales
/// property.
abstract class AuthModuleLocalizations {
  AuthModuleLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AuthModuleLocalizations of(BuildContext context) {
    return Localizations.of<AuthModuleLocalizations>(
      context,
      AuthModuleLocalizations,
    )!;
  }

  static const LocalizationsDelegate<AuthModuleLocalizations> delegate =
      _AuthModuleLocalizationsDelegate();

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

  /// Title of the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account'**
  String get loginTitle;

  /// Label of the email field, on sign-in and sign-up.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// Label of the password field on sign-in.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// Tooltip of the button that reveals the password.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// Tooltip of the button that hides the password again.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// Button that sends the email and password.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginSubmit;

  /// Button on sign-in that opens the sign-up screen.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get loginCreateAccount;

  /// Shown when sign-in fails for a reason the user cannot fix (no connection, server error).
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t sign you in right now. Please try again.'**
  String get loginUnexpectedError;

  /// Shown when the email does not look like an email address.
  ///
  /// In en, this message translates to:
  /// **'Check the email you typed.'**
  String get checkEmail;

  /// Shown on sign-in when the email and password do not match an account.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get loginInvalidCredentials;

  /// Shown on sign-in after the session expired, when the app could not count the changes waiting to be sent.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired, and there may be changes not sent yet. Sign in again to send what is left, or discard it.'**
  String get sessionExpiredMaybeChanges;

  /// Shown on sign-in after the session expired with changes made offline that were not sent. Has a case for zero: in Portuguese, the plural category 'one' covers 0 and 1.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Your session has expired. Sign in again.} =1{Your session has expired, and there is 1 change not sent yet. Sign in again to send it, or discard it.} other{Your session has expired, and there are {count} changes not sent yet. Sign in again to send them, or discard them.}}'**
  String sessionExpiredChanges(int count);

  /// Button on sign-in that discards the changes left by an expired session.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discardChanges;

  /// Title of the dialog that confirms discarding the changes of an expired session.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChangesTitle;

  /// Body of the dialog that confirms discarding the changes of an expired session.
  ///
  /// In en, this message translates to:
  /// **'What was done offline will be deleted from this device and cannot be sent later.'**
  String get discardChangesMessage;

  /// Confirm button of the discard dialog.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// Cancel button of the module's dialogs.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Title of the sign-up screen.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get registerTitle;

  /// Label of the name field on sign-up.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// Label of the password field on sign-up, with the minimum length.
  ///
  /// In en, this message translates to:
  /// **'Password (at least {minLength} characters)'**
  String registerPasswordLabel(int minLength);

  /// Button that sends the sign-up form.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerSubmit;

  /// Shown when sign-up fails for a reason the user cannot fix (no connection, server error).
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t create the account right now. Please try again.'**
  String get registerUnexpectedError;

  /// Shown on sign-up when the password is too short or on the list of compromised passwords.
  ///
  /// In en, this message translates to:
  /// **'Choose another password: at least {minLength} characters, and not a well-known one.'**
  String registerWeakPassword(int minLength);

  /// Shown on sign-up when the email is already registered.
  ///
  /// In en, this message translates to:
  /// **'This email already has an account. Go back and sign in with it.'**
  String get registerEmailTaken;

  /// Shown on sign-up when the server rejects the data for another reason.
  ///
  /// In en, this message translates to:
  /// **'Check your details and try again.'**
  String get registerCheckData;

  /// Button that signs the user out, shown below the signed-in screens.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logout;

  /// Title of the dialog shown before signing out with changes not sent.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get logoutTitle;

  /// Body of the sign-out dialog when there are changes waiting to be sent. Has a case for zero: in Portuguese, the plural category 'one' covers 0 and 1.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No change made offline is waiting to be sent.} =1{1 change made offline has not been sent yet and will be lost.} other{{count} changes made offline have not been sent yet and will be lost.}}'**
  String logoutLostChanges(int count);

  /// Body of the sign-out dialog when the app could not count the changes waiting to be sent.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t check for changes not sent yet. If there are any, they will be lost.'**
  String get logoutCheckFailed;

  /// Confirm button of the sign-out dialog.
  ///
  /// In en, this message translates to:
  /// **'Sign out anyway'**
  String get logoutConfirm;
}

class _AuthModuleLocalizationsDelegate
    extends LocalizationsDelegate<AuthModuleLocalizations> {
  const _AuthModuleLocalizationsDelegate();

  @override
  Future<AuthModuleLocalizations> load(Locale locale) {
    return SynchronousFuture<AuthModuleLocalizations>(
      lookupAuthModuleLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AuthModuleLocalizationsDelegate old) => false;
}

AuthModuleLocalizations lookupAuthModuleLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AuthModuleLocalizationsEn();
    case 'pt':
      return AuthModuleLocalizationsPt();
  }

  throw FlutterError(
    'AuthModuleLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
