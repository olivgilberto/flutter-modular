import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'mobile_tarefas_localizations_en.dart';
import 'mobile_tarefas_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of MobileTarefasLocalizations
/// returned by `MobileTarefasLocalizations.of(context)`.
///
/// Applications need to include `MobileTarefasLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/mobile_tarefas_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: MobileTarefasLocalizations.localizationsDelegates,
///   supportedLocales: MobileTarefasLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the MobileTarefasLocalizations.supportedLocales
/// property.
abstract class MobileTarefasLocalizations {
  MobileTarefasLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static MobileTarefasLocalizations of(BuildContext context) {
    return Localizations.of<MobileTarefasLocalizations>(
      context,
      MobileTarefasLocalizations,
    )!;
  }

  static const LocalizationsDelegate<MobileTarefasLocalizations> delegate =
      _MobileTarefasLocalizationsDelegate();

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

  /// Name of the app, used by the operating system's task switcher.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get appTitle;

  /// Notice below every screen when the device has no network.
  ///
  /// In en, this message translates to:
  /// **'No connection. What you do is kept and sent when the connection is back.'**
  String get connectivityOffline;

  /// Notice below every screen when the network is up but the server does not answer.
  ///
  /// In en, this message translates to:
  /// **'No access to the server. What you do is kept and sent as soon as it answers.'**
  String get connectivityNoInternet;

  /// Non-blocking notice at the top of the screen when the device seems rooted or jailbroken (chapter 38).
  ///
  /// In en, this message translates to:
  /// **'This device seems to be rooted or jailbroken. The app keeps working, but the data stored on it is less protected.'**
  String get deviceIntegrityWarning;

  /// Button that dismisses the rooted/jailbroken device notice.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get deviceIntegrityDismiss;
}

class _MobileTarefasLocalizationsDelegate
    extends LocalizationsDelegate<MobileTarefasLocalizations> {
  const _MobileTarefasLocalizationsDelegate();

  @override
  Future<MobileTarefasLocalizations> load(Locale locale) {
    return SynchronousFuture<MobileTarefasLocalizations>(
      lookupMobileTarefasLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_MobileTarefasLocalizationsDelegate old) => false;
}

MobileTarefasLocalizations lookupMobileTarefasLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return MobileTarefasLocalizationsEn();
    case 'pt':
      return MobileTarefasLocalizationsPt();
  }

  throw FlutterError(
    'MobileTarefasLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
