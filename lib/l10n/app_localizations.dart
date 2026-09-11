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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('pt')];

  /// No description provided for @continueText.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error.'**
  String get unknownError;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @networkFee.
  ///
  /// In en, this message translates to:
  /// **'Network Fee'**
  String get networkFee;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @addressCopied.
  ///
  /// In en, this message translates to:
  /// **'Address copied to clipboard'**
  String get addressCopied;

  /// No description provided for @fieldEmptyError.
  ///
  /// In en, this message translates to:
  /// **'This field cannot be empty.'**
  String get fieldEmptyError;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get welcomeTitle;

  /// No description provided for @welcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Skylight Wallet is one of the simplest Monero wallets. We will help you set up a wallet and connect to a server.'**
  String get welcomeDescription;

  /// No description provided for @welcomeGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get welcomeGetStarted;

  /// No description provided for @welcomeAgreePrefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to the '**
  String get welcomeAgreePrefix;

  /// No description provided for @welcomeTermsLink.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get welcomeTermsLink;

  /// No description provided for @welcomeAgreeMiddle.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get welcomeAgreeMiddle;

  /// No description provided for @welcomePrivacyLink.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get welcomePrivacyLink;

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

  /// No description provided for @lwsSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection Setup'**
  String get lwsSetupTitle;

  /// No description provided for @lwsSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect to a Monero light-wallet server (LWS) or your own full node. Only select a server you trust. Even if you use Tor, this server can learn information about you. With an LWS, your private view key and primary address will be shared with this server.'**
  String get lwsSetupDescription;

  /// No description provided for @lwsSetupAddressHint.
  ///
  /// In en, this message translates to:
  /// **'lws.example.com:18090'**
  String get lwsSetupAddressHint;

  /// No description provided for @lwsSetupProxyPortLabel.
  ///
  /// In en, this message translates to:
  /// **'HTTP Proxy Port (Optional)'**
  String get lwsSetupProxyPortLabel;

  /// No description provided for @lwsSetupProxyPortHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 4444 for I2P'**
  String get lwsSetupProxyPortHint;

  /// No description provided for @lwsSetupUseTorLabel.
  ///
  /// In en, this message translates to:
  /// **'Use Tor'**
  String get lwsSetupUseTorLabel;

  /// No description provided for @lwsSetupTestConnectionButton.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get lwsSetupTestConnectionButton;

  /// No description provided for @lwsSetupStartingTor.
  ///
  /// In en, this message translates to:
  /// **'Starting Tor...'**
  String get lwsSetupStartingTor;

  /// No description provided for @lwsSetupContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get lwsSetupContinueButton;

  /// No description provided for @connectionTypeLws.
  ///
  /// In en, this message translates to:
  /// **'Light Wallet Server'**
  String get connectionTypeLws;

  /// No description provided for @connectionTypeNode.
  ///
  /// In en, this message translates to:
  /// **'Monero Node'**
  String get connectionTypeNode;

  /// No description provided for @connectionNodeAddressHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. node.example.com:18081'**
  String get connectionNodeAddressHint;

  /// No description provided for @connectionRemoteIpNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Connections to remote IP addresses aren\'t allowed. Use a domain name or a local IP address.'**
  String get connectionRemoteIpNotAllowed;

  /// No description provided for @connectionProtocolHttps.
  ///
  /// In en, this message translates to:
  /// **'Removing protocol. Using HTTPS for domains.'**
  String get connectionProtocolHttps;

  /// No description provided for @connectionProtocolHttp.
  ///
  /// In en, this message translates to:
  /// **'Removing protocol. Using HTTP for local addresses.'**
  String get connectionProtocolHttp;

  /// No description provided for @connectionTestStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get connectionTestStop;

  /// No description provided for @connectionTestingTitle.
  ///
  /// In en, this message translates to:
  /// **'Testing connection'**
  String get connectionTestingTitle;

  /// No description provided for @connectionTestingDetail.
  ///
  /// In en, this message translates to:
  /// **'Checking whether the server answers.'**
  String get connectionTestingDetail;

  /// No description provided for @connectionTestAgain.
  ///
  /// In en, this message translates to:
  /// **'Test again'**
  String get connectionTestAgain;

  /// No description provided for @connectionResultWorksTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection works'**
  String get connectionResultWorksTitle;

  /// No description provided for @connectionResultFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not reach this server'**
  String get connectionResultFailedTitle;

  /// No description provided for @connectionResultFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'Nothing answered. Check the address and port, and whether the server accepts your connection.'**
  String get connectionResultFailedDetail;

  /// No description provided for @connectionReachedOverTor.
  ///
  /// In en, this message translates to:
  /// **'Reached over Tor'**
  String get connectionReachedOverTor;

  /// No description provided for @connectionReachedViaProxy.
  ///
  /// In en, this message translates to:
  /// **'Reached through your proxy'**
  String get connectionReachedViaProxy;

  /// No description provided for @connectionReachedDirect.
  ///
  /// In en, this message translates to:
  /// **'Reached directly'**
  String get connectionReachedDirect;

  /// No description provided for @connectionIndicatorHttps.
  ///
  /// In en, this message translates to:
  /// **'HTTPS'**
  String get connectionIndicatorHttps;

  /// No description provided for @connectionIndicatorLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get connectionIndicatorLocal;

  /// No description provided for @connectionIndicatorTorInternal.
  ///
  /// In en, this message translates to:
  /// **'Internal Tor'**
  String get connectionIndicatorTorInternal;

  /// No description provided for @connectionIndicatorTorExternal.
  ///
  /// In en, this message translates to:
  /// **'Using Port {port}'**
  String connectionIndicatorTorExternal(String port);

  /// No description provided for @settingsConnectionSettingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Connection Settings'**
  String get settingsConnectionSettingsLabel;

  /// No description provided for @settingsConnectionServerLws.
  ///
  /// In en, this message translates to:
  /// **'LWS'**
  String get settingsConnectionServerLws;

  /// No description provided for @settingsConnectionServerNode.
  ///
  /// In en, this message translates to:
  /// **'Node'**
  String get settingsConnectionServerNode;

  /// No description provided for @settingsConnectionOverTor.
  ///
  /// In en, this message translates to:
  /// **'over Tor'**
  String get settingsConnectionOverTor;

  /// No description provided for @settingsConnectionOverClearnet.
  ///
  /// In en, this message translates to:
  /// **'over Clearnet'**
  String get settingsConnectionOverClearnet;

  /// No description provided for @settingsConnectionInLocalNetwork.
  ///
  /// In en, this message translates to:
  /// **'in Local Network'**
  String get settingsConnectionInLocalNetwork;

  /// No description provided for @settingsBackgroundSyncLabel.
  ///
  /// In en, this message translates to:
  /// **'Background Sync'**
  String get settingsBackgroundSyncLabel;

  /// No description provided for @settingsBackgroundSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Periodically sync Monero in the background so it\'s up to date when you open the app. Only runs while charging and on WiFi.'**
  String get settingsBackgroundSyncDescription;

  /// No description provided for @settingsForegroundSyncLabel.
  ///
  /// In en, this message translates to:
  /// **'Continuous Sync'**
  String get settingsForegroundSyncLabel;

  /// No description provided for @settingsForegroundSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep Monero syncing continuously while the app runs in the background, with a persistent notification. Uses more battery.'**
  String get settingsForegroundSyncDescription;

  /// No description provided for @homeBlocksRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} blocks left'**
  String homeBlocksRemaining(String count);

  /// No description provided for @fiatApiSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Price Display Setup'**
  String get fiatApiSetupTitle;

  /// No description provided for @fiatApiSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'Skylight Wallet can automatically fetch the latest Monero price. Your balances are not sent to the server. How do you want to fetch this price data?'**
  String get fiatApiSetupDescription;

  /// No description provided for @fiatApiSettingsModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get fiatApiSettingsModeLabel;

  /// No description provided for @fiatApiSettingsModeTorOnly.
  ///
  /// In en, this message translates to:
  /// **'Tor-Only'**
  String get fiatApiSettingsModeTorOnly;

  /// No description provided for @fiatApiSettingsModeClearnet.
  ///
  /// In en, this message translates to:
  /// **'Clearnet-Only (Not Private)'**
  String get fiatApiSettingsModeClearnet;

  /// No description provided for @fiatApiSettingsModeDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get fiatApiSettingsModeDisabled;

  /// No description provided for @fiatModeTorOnlyDesc.
  ///
  /// In en, this message translates to:
  /// **'Prices fetched over Tor · recommended'**
  String get fiatModeTorOnlyDesc;

  /// No description provided for @fiatModeClearnetDesc.
  ///
  /// In en, this message translates to:
  /// **'Not private, the price server sees your IP address'**
  String get fiatModeClearnetDesc;

  /// No description provided for @fiatModeDisabledDesc.
  ///
  /// In en, this message translates to:
  /// **'No prices fetched, balances shown in crypto only'**
  String get fiatModeDisabledDesc;

  /// No description provided for @fiatApiSettingsDisplayCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Currency'**
  String get fiatApiSettingsDisplayCurrencyLabel;

  /// No description provided for @createWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet Setup'**
  String get createWalletTitle;

  /// No description provided for @createWalletDescription.
  ///
  /// In en, this message translates to:
  /// **'Would you like to create a new wallet or restore an existing wallet?'**
  String get createWalletDescription;

  /// No description provided for @createWalletRestoreExistingButton.
  ///
  /// In en, this message translates to:
  /// **'Restore Existing'**
  String get createWalletRestoreExistingButton;

  /// No description provided for @createWalletRestoreExistingDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter an existing Monero seed'**
  String get createWalletRestoreExistingDesc;

  /// No description provided for @createWalletCreateNewButton.
  ///
  /// In en, this message translates to:
  /// **'Create New'**
  String get createWalletCreateNewButton;

  /// No description provided for @createWalletCreateNewDesc.
  ///
  /// In en, this message translates to:
  /// **'Skylight Wallet generates a new polyseed'**
  String get createWalletCreateNewDesc;

  /// No description provided for @createWalletPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Wallet Password'**
  String get createWalletPasswordTitle;

  /// No description provided for @createWalletPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a password to protect your wallet. This password will be required to unlock your wallet.'**
  String get createWalletPasswordDescription;

  /// No description provided for @createWalletPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get createWalletPasswordHint;

  /// No description provided for @createWalletConfirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password'**
  String get createWalletConfirmPasswordHint;

  /// No description provided for @passwordTooShortError.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters long.'**
  String get passwordTooShortError;

  /// No description provided for @passwordsDoNotMatchError.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordsDoNotMatchError;

  /// No description provided for @generateSeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Write these down, in order'**
  String get generateSeedTitle;

  /// No description provided for @generateSeedTitleCovered.
  ///
  /// In en, this message translates to:
  /// **'Seed Phrase'**
  String get generateSeedTitleCovered;

  /// No description provided for @generateSeedDescription.
  ///
  /// In en, this message translates to:
  /// **'This is your polyseed. Write it down and keep it in a safe place.'**
  String get generateSeedDescription;

  /// No description provided for @generateSeedSubtitleCovered.
  ///
  /// In en, this message translates to:
  /// **'These words, in this order, are your wallet. Write them down and keep them in a physical safe. If you lose these words or if you share them with anyone else, you will lose your money permanently. Careful planning now avoids a potential disaster later.'**
  String get generateSeedSubtitleCovered;

  /// No description provided for @generateSeedSubtitleRevealed.
  ///
  /// In en, this message translates to:
  /// **'Securely save these. Do not share them.'**
  String get generateSeedSubtitleRevealed;

  /// No description provided for @generateSeedScreenshotNote.
  ///
  /// In en, this message translates to:
  /// **'Screenshots are blocked on this screen. Make sure nobody is looking over your shoulder.'**
  String get generateSeedScreenshotNote;

  /// No description provided for @generateSeedReveal.
  ///
  /// In en, this message translates to:
  /// **'Tap to reveal'**
  String get generateSeedReveal;

  /// No description provided for @generateSeedConfirm.
  ///
  /// In en, this message translates to:
  /// **'I have written down all the words and stored them somewhere only I can reach.'**
  String get generateSeedConfirm;

  /// No description provided for @generateSeedContinueButton.
  ///
  /// In en, this message translates to:
  /// **'I Wrote It Down'**
  String get generateSeedContinueButton;

  /// No description provided for @lwsDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet Details'**
  String get lwsDetailsTitle;

  /// No description provided for @lwsDetailsDescription.
  ///
  /// In en, this message translates to:
  /// **'If your Monero light wallet server (LWS) requires registration, you can use these details to add this wallet to that server. Not all servers require registration.'**
  String get lwsDetailsDescription;

  /// No description provided for @lwsDetailsPrimaryAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary Address'**
  String get lwsDetailsPrimaryAddressLabel;

  /// No description provided for @lwsDetailsSecretViewKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Secret View Key'**
  String get lwsDetailsSecretViewKeyLabel;

  /// No description provided for @lwsDetailsRestoreHeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Restore Height'**
  String get lwsDetailsRestoreHeightLabel;

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
  /// **'Restore Height (optional)'**
  String get restoreWalletRestoreHeightLabel;

  /// No description provided for @restoreWalletRestoreDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Restore Date (optional)'**
  String get restoreWalletRestoreDateLabel;

  /// No description provided for @restoreWalletScanFrom.
  ///
  /// In en, this message translates to:
  /// **'Scan from'**
  String get restoreWalletScanFrom;

  /// No description provided for @restoreWalletScanFromReason.
  ///
  /// In en, this message translates to:
  /// **'Skip irrelevant history to save time'**
  String get restoreWalletScanFromReason;

  /// No description provided for @restoreWalletNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get restoreWalletNotSet;

  /// No description provided for @restoreScanTitle.
  ///
  /// In en, this message translates to:
  /// **'When did this wallet first receive funds?'**
  String get restoreScanTitle;

  /// No description provided for @restoreScanDescription.
  ///
  /// In en, this message translates to:
  /// **'Skylight Wallet can skip irrelevant history to save you time. Either pick the first month that you used the wallet or select I\'m not sure to check everything. It\'s okay to pick a month that is too early, but it\'s bad to pick a month that is too late.'**
  String get restoreScanDescription;

  /// No description provided for @restoreScanPickMonth.
  ///
  /// In en, this message translates to:
  /// **'Pick a month'**
  String get restoreScanPickMonth;

  /// No description provided for @restoreScanNotSure.
  ///
  /// In en, this message translates to:
  /// **'I\'m not sure'**
  String get restoreScanNotSure;

  /// No description provided for @restoreScanNotSureDesc.
  ///
  /// In en, this message translates to:
  /// **'Scan everything. Slower this first setup but not any slower later. Always complete.'**
  String get restoreScanNotSureDesc;

  /// No description provided for @restoreScanFromStart.
  ///
  /// In en, this message translates to:
  /// **'Genesis'**
  String get restoreScanFromStart;

  /// No description provided for @restoreScanDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get restoreScanDone;

  /// No description provided for @restoreWalletRestoreButton.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreWalletRestoreButton;

  /// No description provided for @restoreWalletInvalidMnemonic.
  ///
  /// In en, this message translates to:
  /// **'Invalid seed.'**
  String get restoreWalletInvalidMnemonic;

  /// No description provided for @restoreWalletSeedLength.
  ///
  /// In en, this message translates to:
  /// **'Seed length'**
  String get restoreWalletSeedLength;

  /// No description provided for @restoreWalletPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get restoreWalletPaste;

  /// No description provided for @restoreWalletSeedTypePolyseed.
  ///
  /// In en, this message translates to:
  /// **'Polyseed'**
  String get restoreWalletSeedTypePolyseed;

  /// No description provided for @restoreWalletSeedTypeBip39.
  ///
  /// In en, this message translates to:
  /// **'BIP39'**
  String get restoreWalletSeedTypeBip39;

  /// No description provided for @restoreWalletSeedTypeLegacy.
  ///
  /// In en, this message translates to:
  /// **'Legacy'**
  String get restoreWalletSeedTypeLegacy;

  /// No description provided for @restoreWalletBadWord.
  ///
  /// In en, this message translates to:
  /// **'Word {position} isn\'t a BIP39 word.'**
  String restoreWalletBadWord(int position);

  /// No description provided for @restoreWalletDidYouMean.
  ///
  /// In en, this message translates to:
  /// **'Did you mean {word}?'**
  String restoreWalletDidYouMean(String word);

  /// No description provided for @restoreWalletChecksumError.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a valid seed phrase — check the words and their order.'**
  String get restoreWalletChecksumError;

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

  /// No description provided for @unlockButton.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlockButton;

  /// No description provided for @unlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Wallet'**
  String get unlockReason;

  /// No description provided for @unlockUnableToAuthError.
  ///
  /// In en, this message translates to:
  /// **'Unable to authenticate.'**
  String get unlockUnableToAuthError;

  /// No description provided for @unlockWithFaceId.
  ///
  /// In en, this message translates to:
  /// **'Unlock with Face ID'**
  String get unlockWithFaceId;

  /// No description provided for @unlockWithTouchId.
  ///
  /// In en, this message translates to:
  /// **'Unlock with Touch ID'**
  String get unlockWithTouchId;

  /// No description provided for @unlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock Wallet'**
  String get unlockTitle;

  /// No description provided for @unlockDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter your wallet password to unlock'**
  String get unlockDescription;

  /// No description provided for @unlockPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get unlockPasswordLabel;

  /// No description provided for @unlockPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get unlockPasswordHint;

  /// No description provided for @unlockIncorrectPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Please try again.'**
  String get unlockIncorrectPasswordError;

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

  /// No description provided for @homeBalanceLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get homeBalanceLocked;

  /// No description provided for @homeTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get homeTransactionsTitle;

  /// No description provided for @homeOutgoingTxSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Outgoing Transaction'**
  String get homeOutgoingTxSemanticLabel;

  /// No description provided for @homeIncomingTxSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Incoming Transaction'**
  String get homeIncomingTxSemanticLabel;

  /// No description provided for @homeTransactionConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get homeTransactionConfirmed;

  /// No description provided for @homeNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No Transactions'**
  String get homeNoTransactions;

  /// No description provided for @homeFiatApiError.
  ///
  /// In en, this message translates to:
  /// **'Error connecting to price server'**
  String get homeFiatApiError;

  /// No description provided for @homeDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get homeDisconnected;

  /// No description provided for @coinHomeActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get coinHomeActivityTitle;

  /// No description provided for @coinHomeReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get coinHomeReceived;

  /// No description provided for @coinHomeSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get coinHomeSent;

  /// No description provided for @receiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receiveTitle;

  /// No description provided for @receivePrimaryAddressWarn.
  ///
  /// In en, this message translates to:
  /// **'Warning: Unless you know what you\'re doing, please use subaddresses for better privacy.'**
  String get receivePrimaryAddressWarn;

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

  /// No description provided for @receiveServerNoSubaddressesWarn.
  ///
  /// In en, this message translates to:
  /// **'Warning: This server does not support subaddresses. For better privacy, consider using a server that supports them. You are receiving to your primary address.'**
  String get receiveServerNoSubaddressesWarn;

  /// No description provided for @receiveMaxSubaddressesReachedWarn.
  ///
  /// In en, this message translates to:
  /// **'You have reached the maximum number of subaddresses supported by this server. This is a used address.'**
  String get receiveMaxSubaddressesReachedWarn;

  /// No description provided for @receiveSubaddressTab.
  ///
  /// In en, this message translates to:
  /// **'Subaddress'**
  String get receiveSubaddressTab;

  /// No description provided for @receivePrimaryTab.
  ///
  /// In en, this message translates to:
  /// **'Primary address'**
  String get receivePrimaryTab;

  /// No description provided for @receiveCopyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get receiveCopyAddress;

  /// No description provided for @receiveAddressHeading.
  ///
  /// In en, this message translates to:
  /// **'Your {coin} address'**
  String receiveAddressHeading(String coin);

  /// No description provided for @receiveBlockchainSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{coin} blockchain'**
  String receiveBlockchainSubtitle(String coin);

  /// No description provided for @sendTitle.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendTitle;

  /// No description provided for @sendSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendSendButton;

  /// No description provided for @sendTransactionSuccessfullySent.
  ///
  /// In en, this message translates to:
  /// **'Transaction successfully sent!'**
  String get sendTransactionSuccessfullySent;

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

  /// No description provided for @sendInsufficientBalanceToCoverFeeError.
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance to cover the network fee.'**
  String get sendInsufficientBalanceToCoverFeeError;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsSectionGeneral;

  /// No description provided for @settingsSectionBehaviour.
  ///
  /// In en, this message translates to:
  /// **'Behaviour'**
  String get settingsSectionBehaviour;

  /// No description provided for @settingsSectionWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get settingsSectionWallet;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsNotifyNewTxsLabel.
  ///
  /// In en, this message translates to:
  /// **'Transaction Notifications'**
  String get settingsNotifyNewTxsLabel;

  /// No description provided for @settingsNotifyNewTxsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show a notification when you receive a transaction. When connected to a Monero node, Background Sync must also be enabled.'**
  String get settingsNotifyNewTxsDescription;

  /// No description provided for @settingsNotifyNewTxsDescriptionIos.
  ///
  /// In en, this message translates to:
  /// **'Notifications will be delayed for Tor LWS connections.'**
  String get settingsNotifyNewTxsDescriptionIos;

  /// No description provided for @settingsAppLockLabel.
  ///
  /// In en, this message translates to:
  /// **'App Lock'**
  String get settingsAppLockLabel;

  /// No description provided for @settingsAppLockUnlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Wallet'**
  String get settingsAppLockUnlockReason;

  /// No description provided for @settingsAppLockUnableToAuthError.
  ///
  /// In en, this message translates to:
  /// **'Unable to authenticate. Make sure you have device unlock set up.'**
  String get settingsAppLockUnableToAuthError;

  /// No description provided for @settingsVerboseLoggingLabel.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic Logs'**
  String get settingsVerboseLoggingLabel;

  /// No description provided for @settingsVerboseLoggingDescription.
  ///
  /// In en, this message translates to:
  /// **'Log wallet operations to a text file in the app\'s data folder for debugging purposes.'**
  String get settingsVerboseLoggingDescription;

  /// No description provided for @settingsVerboseLoggingDescriptionIos.
  ///
  /// In en, this message translates to:
  /// **'Log wallet operations and allow the logs to be exported to a text file.'**
  String get settingsVerboseLoggingDescriptionIos;

  /// No description provided for @settingsExportLogsLabel.
  ///
  /// In en, this message translates to:
  /// **'Export Logs'**
  String get settingsExportLogsLabel;

  /// No description provided for @settingsExportLogsButton.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get settingsExportLogsButton;

  /// No description provided for @settingsExportLogsError.
  ///
  /// In en, this message translates to:
  /// **'No logs found to export.'**
  String get settingsExportLogsError;

  /// No description provided for @settingsThemeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeLabel;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeLightDesc.
  ///
  /// In en, this message translates to:
  /// **'Light and clean'**
  String get settingsThemeLightDesc;

  /// No description provided for @settingsThemeDarkDesc.
  ///
  /// In en, this message translates to:
  /// **'Dark ground, easier at night'**
  String get settingsThemeDarkDesc;

  /// No description provided for @settingsThemeSystemDesc.
  ///
  /// In en, this message translates to:
  /// **'Follows your phone'**
  String get settingsThemeSystemDesc;

  /// No description provided for @settingsThemeSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a theme to match your style.'**
  String get settingsThemeSheetSubtitle;

  /// No description provided for @settingsLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageLabel;

  /// No description provided for @settingsLanguageSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick your language and localization.'**
  String get settingsLanguageSheetSubtitle;

  /// No description provided for @settingsFiatApiSettingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Price Display Settings'**
  String get settingsFiatApiSettingsLabel;

  /// No description provided for @settingsLwsViewKeysLabel.
  ///
  /// In en, this message translates to:
  /// **'LWS View Keys'**
  String get settingsLwsViewKeysLabel;

  /// No description provided for @settingsLwsViewKeysButton.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get settingsLwsViewKeysButton;

  /// No description provided for @settingsSecretKeysLabel.
  ///
  /// In en, this message translates to:
  /// **'Secret Restore Keys'**
  String get settingsSecretKeysLabel;

  /// No description provided for @settingsSecretKeysButton.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get settingsSecretKeysButton;

  /// No description provided for @settingsViewLwsKeysDialogText.
  ///
  /// In en, this message translates to:
  /// **'Only share this information with your light-wallet server. These keys allow the holder to permanently see all transactions related to your wallets. Sharing these with an untrusted person will significantly harm your privacy.'**
  String get settingsViewLwsKeysDialogText;

  /// No description provided for @settingsViewLwsKeysDialogRevealButton.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get settingsViewLwsKeysDialogRevealButton;

  /// No description provided for @settingsViewSecretKeysDialogText.
  ///
  /// In en, this message translates to:
  /// **'Do not share these keys with anyone, including anyone claiming to be support. If you receive a request to provide these, you are being scammed. If you provide this information to another person, you will lose your money and it cannot be recovered.'**
  String get settingsViewSecretKeysDialogText;

  /// No description provided for @settingsViewSecretKeysDialogRevealButton.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get settingsViewSecretKeysDialogRevealButton;

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

  /// No description provided for @txDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction Details'**
  String get txDetailsTitle;

  /// No description provided for @txDetailsHashLabel.
  ///
  /// In en, this message translates to:
  /// **'Hash'**
  String get txDetailsHashLabel;

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

  /// No description provided for @txDetailsReceivedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Received At'**
  String get txDetailsReceivedAtLabel;

  /// No description provided for @txDetailsChangeRecipientLabel.
  ///
  /// In en, this message translates to:
  /// **'Change Recipient'**
  String get txDetailsChangeRecipientLabel;

  /// No description provided for @unconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Unconfirmed'**
  String get unconfirmed;

  /// No description provided for @txDetailsCopyHint.
  ///
  /// In en, this message translates to:
  /// **'tap any value to copy'**
  String get txDetailsCopyHint;

  /// No description provided for @txDetailsFailed.
  ///
  /// In en, this message translates to:
  /// **'This transaction failed. The funds were not sent.'**
  String get txDetailsFailed;

  /// No description provided for @txDetailsUnknownStatus.
  ///
  /// In en, this message translates to:
  /// **'This transaction was not confirmed as sent. Check before sending again.'**
  String get txDetailsUnknownStatus;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @lwsKeysTitle.
  ///
  /// In en, this message translates to:
  /// **'LWS Keys'**
  String get lwsKeysTitle;

  /// No description provided for @lwsKeysPrimaryAddress.
  ///
  /// In en, this message translates to:
  /// **'Primary Address'**
  String get lwsKeysPrimaryAddress;

  /// No description provided for @lwsKeysRestoreHeight.
  ///
  /// In en, this message translates to:
  /// **'Restore Height'**
  String get lwsKeysRestoreHeight;

  /// No description provided for @lwsKeysSecretViewKey.
  ///
  /// In en, this message translates to:
  /// **'Secret View Key'**
  String get lwsKeysSecretViewKey;

  /// No description provided for @lwsKeysWarning.
  ///
  /// In en, this message translates to:
  /// **'Screenshots are blocked on this screen. Make sure nobody is looking over your shoulder.'**
  String get lwsKeysWarning;

  /// No description provided for @secretKeysTitle.
  ///
  /// In en, this message translates to:
  /// **'Secret Restore Keys'**
  String get secretKeysTitle;

  /// No description provided for @secretKeysDescription.
  ///
  /// In en, this message translates to:
  /// **'These seeds and keys restore full control of your wallet. Anyone who sees them can spend your funds.'**
  String get secretKeysDescription;

  /// No description provided for @secretKeysMnemonic.
  ///
  /// In en, this message translates to:
  /// **'Seed'**
  String get secretKeysMnemonic;

  /// No description provided for @secretKeysPublicSpendKey.
  ///
  /// In en, this message translates to:
  /// **'Public Spend Key'**
  String get secretKeysPublicSpendKey;

  /// No description provided for @secretKeysSecretSpendKey.
  ///
  /// In en, this message translates to:
  /// **'Secret Spend Key'**
  String get secretKeysSecretSpendKey;

  /// No description provided for @secretKeysPublicViewKey.
  ///
  /// In en, this message translates to:
  /// **'Public View Key'**
  String get secretKeysPublicViewKey;

  /// No description provided for @secretKeysWarning.
  ///
  /// In en, this message translates to:
  /// **'Never share these or enter them into any website. Store them offline.'**
  String get secretKeysWarning;

  /// No description provided for @scanQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanQrTitle;

  /// No description provided for @confirmSendTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Send'**
  String get confirmSendTitle;

  /// No description provided for @confirmSendDescription.
  ///
  /// In en, this message translates to:
  /// **'Transactions are irreversible, so make sure that these details match exactly.'**
  String get confirmSendDescription;

  /// No description provided for @confirmSendHighFeeWarning.
  ///
  /// In en, this message translates to:
  /// **'The network fee is {percent} of the amount you are sending.'**
  String confirmSendHighFeeWarning(String percent);

  /// No description provided for @addressBookTitle.
  ///
  /// In en, this message translates to:
  /// **'Address Book'**
  String get addressBookTitle;

  /// No description provided for @addressBookAddContact.
  ///
  /// In en, this message translates to:
  /// **'Add Contact'**
  String get addressBookAddContact;

  /// No description provided for @addressBookEditContact.
  ///
  /// In en, this message translates to:
  /// **'Edit Contact'**
  String get addressBookEditContact;

  /// No description provided for @addressBookDeleteContact.
  ///
  /// In en, this message translates to:
  /// **'Delete Contact'**
  String get addressBookDeleteContact;

  /// No description provided for @addressBookDeleteContactConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{contactName}\"?'**
  String addressBookDeleteContactConfirmation(String contactName);

  /// No description provided for @addressBookDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get addressBookDelete;

  /// No description provided for @addressBookSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search contacts...'**
  String get addressBookSearchHint;

  /// No description provided for @addressBookNoContacts.
  ///
  /// In en, this message translates to:
  /// **'No Contacts Yet'**
  String get addressBookNoContacts;

  /// No description provided for @addressBookNoContactsDescription.
  ///
  /// In en, this message translates to:
  /// **'Add your first contact by tapping the + button'**
  String get addressBookNoContactsDescription;

  /// No description provided for @addressBookNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No Contacts Found'**
  String get addressBookNoSearchResults;

  /// No description provided for @addressBookCopyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy Address'**
  String get addressBookCopyAddress;

  /// No description provided for @addressBookEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get addressBookEdit;

  /// No description provided for @addressBookContactName.
  ///
  /// In en, this message translates to:
  /// **'Contact Name'**
  String get addressBookContactName;

  /// No description provided for @addressBookNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get addressBookNameHint;

  /// No description provided for @addressBookAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Monero address'**
  String get addressBookAddressHint;

  /// No description provided for @addressBookAddDescription.
  ///
  /// In en, this message translates to:
  /// **'A name and a Monero address to pay them on.'**
  String get addressBookAddDescription;

  /// No description provided for @addressBookEditDescription.
  ///
  /// In en, this message translates to:
  /// **'Update this contact\'s name or address.'**
  String get addressBookEditDescription;

  /// No description provided for @addressBookUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get addressBookUpdate;

  /// No description provided for @addressBookSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get addressBookSave;

  /// No description provided for @sendSelectedContact.
  ///
  /// In en, this message translates to:
  /// **'Selected Contact'**
  String get sendSelectedContact;

  /// No description provided for @sendClearSelectedContact.
  ///
  /// In en, this message translates to:
  /// **'Clear Selected Contact'**
  String get sendClearSelectedContact;

  /// No description provided for @sendPriorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get sendPriorityLow;

  /// No description provided for @sendPriorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get sendPriorityNormal;

  /// No description provided for @sendPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get sendPriorityHigh;

  /// No description provided for @sendPriorityLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get sendPriorityLabel;

  /// No description provided for @sendTransactionPriority.
  ///
  /// In en, this message translates to:
  /// **'Transaction Priority'**
  String get sendTransactionPriority;

  /// No description provided for @sendFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get sendFeeLabel;

  /// No description provided for @sendContactsButton.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get sendContactsButton;

  /// No description provided for @sendToLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get sendToLabel;

  /// No description provided for @sendPasteButton.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get sendPasteButton;

  /// No description provided for @sendScanButton.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get sendScanButton;

  /// No description provided for @sendMaxButton.
  ///
  /// In en, this message translates to:
  /// **'MAX'**
  String get sendMaxButton;

  /// No description provided for @sendNetworkFee.
  ///
  /// In en, this message translates to:
  /// **'Network fee'**
  String get sendNetworkFee;

  /// No description provided for @sendPriorityHeading.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get sendPriorityHeading;

  /// No description provided for @sendPickContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Send to a contact'**
  String get sendPickContactTitle;

  /// No description provided for @sendAvailableSuffix.
  ///
  /// In en, this message translates to:
  /// **'available'**
  String get sendAvailableSuffix;

  /// No description provided for @sendFailedToGetFeesError.
  ///
  /// In en, this message translates to:
  /// **'Failed to get fees.'**
  String get sendFailedToGetFeesError;

  /// No description provided for @torInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Tor Built-in'**
  String get torInfoTitle;

  /// No description provided for @torInfoDescription.
  ///
  /// In en, this message translates to:
  /// **'Skylight Wallet automatically uses built-in Tor to protect your internet connections.'**
  String get torInfoDescription;

  /// No description provided for @torInfoContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get torInfoContinueButton;

  /// No description provided for @torInfoConfigureButton.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get torInfoConfigureButton;

  /// No description provided for @torSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tor Settings'**
  String get torSettingsTitle;

  /// No description provided for @torSettingsModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Tor Mode'**
  String get torSettingsModeLabel;

  /// No description provided for @torSettingsModeBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in Tor'**
  String get torSettingsModeBuiltIn;

  /// No description provided for @torSettingsModeExternal.
  ///
  /// In en, this message translates to:
  /// **'External Tor'**
  String get torSettingsModeExternal;

  /// No description provided for @torSettingsModeDisabled.
  ///
  /// In en, this message translates to:
  /// **'No Tor'**
  String get torSettingsModeDisabled;

  /// No description provided for @torChoiceBuiltInDesc.
  ///
  /// In en, this message translates to:
  /// **'Bundled with Skylight Wallet · recommended'**
  String get torChoiceBuiltInDesc;

  /// No description provided for @torChoiceExternalDesc.
  ///
  /// In en, this message translates to:
  /// **'Orbot, or a daemon you run yourself'**
  String get torChoiceExternalDesc;

  /// No description provided for @torChoiceNoTorDesc.
  ///
  /// In en, this message translates to:
  /// **'Servers you connect to can see your IP address'**
  String get torChoiceNoTorDesc;

  /// No description provided for @torChoiceConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected to Tor'**
  String get torChoiceConnected;

  /// No description provided for @torChoiceTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Test failed'**
  String get torChoiceTestFailed;

  /// No description provided for @torChoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Tor Connection Setup'**
  String get torChoiceTitle;

  /// No description provided for @torChoiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tor can hide your IP address from servers you connect to. This does not reduce the information that is stored on public blockchains. In general, how do you want Skylight Wallet to handle Tor connections?'**
  String get torChoiceSubtitle;

  /// No description provided for @torSettingsSocksPortLabel.
  ///
  /// In en, this message translates to:
  /// **'SOCKS Port'**
  String get torSettingsSocksPortLabel;

  /// No description provided for @torSettingsSocksPortHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 9050'**
  String get torSettingsSocksPortHint;

  /// No description provided for @torSettingsUseOrbotLabel.
  ///
  /// In en, this message translates to:
  /// **'Use Orbot/InviZible'**
  String get torSettingsUseOrbotLabel;

  /// No description provided for @torSettingsUseOrbotLabelIos.
  ///
  /// In en, this message translates to:
  /// **'Use Orbot'**
  String get torSettingsUseOrbotLabelIos;

  /// No description provided for @torSettingsSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get torSettingsSaveButton;

  /// No description provided for @torSettingsTestConnectionButton.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get torSettingsTestConnectionButton;

  /// No description provided for @torDisabledWalletsWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable Tor?'**
  String get torDisabledWalletsWarningTitle;

  /// No description provided for @torDisabledWalletsWarningBody.
  ///
  /// In en, this message translates to:
  /// **'Some wallets are set to connect over Tor. Disabling Tor will disconnect them, and they will stay disconnected until you reconfigure their connection.'**
  String get torDisabledWalletsWarningBody;

  /// No description provided for @torDisabledWalletsWarningConfirm.
  ///
  /// In en, this message translates to:
  /// **'Disable Tor'**
  String get torDisabledWalletsWarningConfirm;

  /// No description provided for @settingsTorSettingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tor Settings'**
  String get settingsTorSettingsLabel;

  /// No description provided for @lwsSetupUsingInternalTor.
  ///
  /// In en, this message translates to:
  /// **'Using Internal Tor'**
  String get lwsSetupUsingInternalTor;

  /// No description provided for @lwsSetupUsingExternalTor.
  ///
  /// In en, this message translates to:
  /// **'Using External Tor Proxy at {address}'**
  String lwsSetupUsingExternalTor(String address);

  /// No description provided for @lwsSetupTorDisabledError.
  ///
  /// In en, this message translates to:
  /// **'Tor is disabled. Please go back and enable it.'**
  String get lwsSetupTorDisabledError;

  /// No description provided for @lwsSetupInvalidQrCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid connection address.'**
  String get lwsSetupInvalidQrCode;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'pt'].contains(locale.languageCode);

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
