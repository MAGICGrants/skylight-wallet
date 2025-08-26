import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

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
    Locale('pt'),
  ];

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get welcomeTitle;

  /// No description provided for @welcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Light Monero Wallet is one of the simplest Monero wallets. We will help you set up a wallet and connect to a server.'**
  String get welcomeDescription;

  /// No description provided for @welcomeGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get welcomeGetStarted;

  /// No description provided for @restoreWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore Warning'**
  String get restoreWarningTitle;

  /// No description provided for @restoreWarningDescription.
  ///
  /// In en, this message translates to:
  /// **'Are you sure? The server that you connect to will be able to see your past and future Monero transaction history.'**
  String get restoreWarningDescription;

  /// No description provided for @restoreWarningContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get restoreWarningContinueButton;

  /// No description provided for @connectionSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection Setup'**
  String get connectionSetupTitle;

  /// No description provided for @connectionSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'Let\'s setup a connection with LWS.'**
  String get connectionSetupDescription;

  /// No description provided for @connectionSetupAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get connectionSetupAddressLabel;

  /// No description provided for @connectionSetupAddressHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 192.168.1.1:18090 or example.com:18090'**
  String get connectionSetupAddressHint;

  /// No description provided for @connectionSetupProxyPortLabel.
  ///
  /// In en, this message translates to:
  /// **'Proxy Port (optional)'**
  String get connectionSetupProxyPortLabel;

  /// No description provided for @connectionSetupProxyPortHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 4444 for I2P'**
  String get connectionSetupProxyPortHint;

  /// No description provided for @connectionSetupUseTorLabel.
  ///
  /// In en, this message translates to:
  /// **'Use Tor'**
  String get connectionSetupUseTorLabel;

  /// No description provided for @connectionSetupUseSslLabel.
  ///
  /// In en, this message translates to:
  /// **'Use SSL'**
  String get connectionSetupUseSslLabel;

  /// No description provided for @connectionSetupTestConnectionButton.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get connectionSetupTestConnectionButton;

  /// No description provided for @connectionSetupContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get connectionSetupContinueButton;

  /// No description provided for @createWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Wallet'**
  String get createWalletTitle;

  /// No description provided for @createWalletDescription.
  ///
  /// In en, this message translates to:
  /// **'Do you already have a Monero wallet seed, or do you need to make a new one?'**
  String get createWalletDescription;

  /// No description provided for @createWalletRestoreExistingButton.
  ///
  /// In en, this message translates to:
  /// **'Restore Existing'**
  String get createWalletRestoreExistingButton;

  /// No description provided for @createWalletCreateNewButton.
  ///
  /// In en, this message translates to:
  /// **'Create New'**
  String get createWalletCreateNewButton;

  /// No description provided for @generateSeedTitle.
  ///
  /// In en, this message translates to:
  /// **'New Wallet'**
  String get generateSeedTitle;

  /// No description provided for @generateSeedDescription.
  ///
  /// In en, this message translates to:
  /// **'This is your polyseed. Write it down and keep it in a safe place.'**
  String get generateSeedDescription;

  /// No description provided for @generateSeedContinueButton.
  ///
  /// In en, this message translates to:
  /// **'I wrote it down'**
  String get generateSeedContinueButton;

  /// No description provided for @restoreWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore Wallet'**
  String get restoreWalletTitle;

  /// No description provided for @restoreWalletDescription.
  ///
  /// In en, this message translates to:
  /// **'Input your Monero seed below. We will check common formats.'**
  String get restoreWalletDescription;

  /// No description provided for @restoreWalletSeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Seed'**
  String get restoreWalletSeedLabel;

  /// No description provided for @restoreWalletRestoreHeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Restore Height'**
  String get restoreWalletRestoreHeightLabel;

  /// No description provided for @restoreWalletRestoreButton.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreWalletRestoreButton;

  /// No description provided for @navigationBarWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get navigationBarWallet;

  /// No description provided for @navigationBarSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navigationBarSettings;

  /// No description provided for @homeConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get homeConnecting;

  /// No description provided for @homeSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get homeSyncing;

  /// No description provided for @homeHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get homeHeight;

  /// No description provided for @homeReceive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get homeReceive;

  /// No description provided for @homeSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get homeSend;

  /// No description provided for @receivePrimaryAddressWarn.
  ///
  /// In en, this message translates to:
  /// **'Warning: For better privacy, consider using subaddresses if supported by your light wallet server.'**
  String get receivePrimaryAddressWarn;

  /// No description provided for @receiveSubaddressWarn.
  ///
  /// In en, this message translates to:
  /// **'Warning: Make sure your light wallet server supports subaddresses, otherwise, you will not be able to see incoming transactions.'**
  String get receiveSubaddressWarn;

  /// No description provided for @receiveShareButton.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get receiveShareButton;

  /// No description provided for @receiveShowSubaddressButton.
  ///
  /// In en, this message translates to:
  /// **'Show Subaddress'**
  String get receiveShowSubaddressButton;

  /// No description provided for @receiveShowPrimaryAddressButton.
  ///
  /// In en, this message translates to:
  /// **'Show Primary Address'**
  String get receiveShowPrimaryAddressButton;

  /// No description provided for @sendTitle.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendTitle;

  /// No description provided for @sendAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get sendAddressLabel;

  /// No description provided for @sendAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get sendAmountLabel;

  /// No description provided for @sendSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendSendButton;

  /// No description provided for @sendOpenAliasResolveError.
  ///
  /// In en, this message translates to:
  /// **'Invalid OpenAlias.'**
  String get sendOpenAliasResolveError;

  /// No description provided for @sendInvalidAddressError.
  ///
  /// In en, this message translates to:
  /// **'Invalid address.'**
  String get sendInvalidAddressError;

  /// No description provided for @sendInsufficientBalanceError.
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance.'**
  String get sendInsufficientBalanceError;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsNotifyNewTxs.
  ///
  /// In en, this message translates to:
  /// **'Notify New Transactions'**
  String get settingsNotifyNewTxs;

  /// No description provided for @settingsLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageLabel;

  /// No description provided for @settingsDeleteWalletButton.
  ///
  /// In en, this message translates to:
  /// **'Delete Wallet'**
  String get settingsDeleteWalletButton;

  /// No description provided for @settingsDeleteWalletDialogText.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your wallet? You will lose access to your funds unless you have backed up your seed phrase.'**
  String get settingsDeleteWalletDialogText;

  /// No description provided for @settingsDeleteWalletDialogDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingsDeleteWalletDialogDeleteButton;

  /// No description provided for @txDetailsHashLabel.
  ///
  /// In en, this message translates to:
  /// **'Hash'**
  String get txDetailsHashLabel;

  /// No description provided for @txDetailsAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get txDetailsAmountLabel;

  /// No description provided for @txDetailsFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get txDetailsFeeLabel;

  /// No description provided for @txDetailsTimeAndDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Time and Date'**
  String get txDetailsTimeAndDateLabel;

  /// No description provided for @txDetailsConfirmationHeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirmation Height'**
  String get txDetailsConfirmationHeightLabel;

  /// No description provided for @txDetailsConfirmationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirmations'**
  String get txDetailsConfirmationsLabel;

  /// No description provided for @txDetailsViewKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'View Key'**
  String get txDetailsViewKeyLabel;

  /// No description provided for @txDetailsRecipientsLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipients'**
  String get txDetailsRecipientsLabel;
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
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
