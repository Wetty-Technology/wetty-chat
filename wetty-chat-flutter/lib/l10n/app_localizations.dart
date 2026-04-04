import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('zh'),
    Locale('zh', 'CN'),
    Locale('zh', 'TW'),
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'Wetty Chat'**
  String get appTitle;

  /// Bottom tab label for chats
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get tabChats;

  /// Bottom tab label for settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// Login button / page title
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Login info section header
  ///
  /// In en, this message translates to:
  /// **'Login Info'**
  String get loginInfo;

  /// Username field label
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Security question section header
  ///
  /// In en, this message translates to:
  /// **'Security Question'**
  String get securityQuestion;

  /// Security question hint text
  ///
  /// In en, this message translates to:
  /// **'Security question (ignore if not set)'**
  String get securityQuestionHint;

  /// Security question option
  ///
  /// In en, this message translates to:
  /// **'Mother\'s name'**
  String get sqMothersName;

  /// Security question option
  ///
  /// In en, this message translates to:
  /// **'Grandfather\'s name'**
  String get sqGrandfathersName;

  /// Security question option
  ///
  /// In en, this message translates to:
  /// **'Father\'s birth city'**
  String get sqFathersBirthCity;

  /// Security question option
  ///
  /// In en, this message translates to:
  /// **'Name of one of your teachers'**
  String get sqTeachersName;

  /// Security question option
  ///
  /// In en, this message translates to:
  /// **'Your computer model'**
  String get sqComputerModel;

  /// Security question option
  ///
  /// In en, this message translates to:
  /// **'Your favorite restaurant'**
  String get sqFavoriteRestaurant;

  /// Security question option
  ///
  /// In en, this message translates to:
  /// **'Last 4 digits of driver\'s license'**
  String get sqDriversLicenseLast4;

  /// Toast shown on successful login
  ///
  /// In en, this message translates to:
  /// **'Login successful'**
  String get loginSuccess;

  /// Toast shown on failed login
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailed;

  /// Error when required fields are empty
  ///
  /// In en, this message translates to:
  /// **'Missing fields'**
  String get missingFields;

  /// Status while request is in progress
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processing;

  /// Status when ready
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// New chat page title
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get newChat;

  /// Chat name field label
  ///
  /// In en, this message translates to:
  /// **'Chat Name'**
  String get chatName;

  /// Placeholder for optional fields
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// Create button label
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Toast shown when chat is created
  ///
  /// In en, this message translates to:
  /// **'Chat created'**
  String get chatCreated;

  /// Placeholder when chat has no messages
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// Group members page title
  ///
  /// In en, this message translates to:
  /// **'Group Members'**
  String get groupMembers;

  /// Group settings page title
  ///
  /// In en, this message translates to:
  /// **'Group Settings'**
  String get groupSettings;

  /// Placeholder when group has no members
  ///
  /// In en, this message translates to:
  /// **'No members'**
  String get noMembers;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Language setting label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// System language option
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Simplified Chinese language option
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get languageChineseCN;

  /// Traditional Chinese language option
  ///
  /// In en, this message translates to:
  /// **'Traditional Chinese'**
  String get languageChineseTW;

  /// Text size setting label
  ///
  /// In en, this message translates to:
  /// **'Text Size'**
  String get settingsTextSize;

  /// General settings section header
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// User settings section header
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get settingsUser;

  /// Profile setting label
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfile;

  /// Notifications setting label
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// Log out button label
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// Log out confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logOutConfirmTitle;

  /// Log out confirmation dialog message
  ///
  /// In en, this message translates to:
  /// **'This will clear the login state saved on this device.'**
  String get logOutConfirmMessage;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// OK button label
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Error dialog title
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Close button label
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Toast shown when text is copied
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// Font size settings page title
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get fontSize;

  /// Messages font size label
  ///
  /// In en, this message translates to:
  /// **'Messages Font Size'**
  String get messagesFontSize;

  /// Example user name in font size preview
  ///
  /// In en, this message translates to:
  /// **'Sample User'**
  String get sampleUser;

  /// Font size preview sample message
  ///
  /// In en, this message translates to:
  /// **'This is how your messages will look in chat.'**
  String get fontSizePreviewMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'CN':
            return AppLocalizationsZhCn();
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
