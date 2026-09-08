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

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @fieldEmptyError.
  ///
  /// In en, this message translates to:
  /// **'This field cannot be empty.'**
  String get fieldEmptyError;

  /// No description provided for @welcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'A self-custody wallet for Monero, Bitcoin, Ethereum and DAI. Your keys never leave this device.'**
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

  /// No description provided for @torChoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'How should Spice Wallet reach the network?'**
  String get torChoiceTitle;

  /// No description provided for @torChoiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing connects until you choose. Tor hides your IP address from the servers Spice Wallet talks to.'**
  String get torChoiceSubtitle;

  /// No description provided for @torChoiceBuiltInDesc.
  ///
  /// In en, this message translates to:
  /// **'Bundled with Spice Wallet · recommended'**
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

  /// No description provided for @torChoiceOrbot.
  ///
  /// In en, this message translates to:
  /// **'Use Orbot — port is fixed at 9050'**
  String get torChoiceOrbot;

  /// No description provided for @torChoiceTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Test failed'**
  String get torChoiceTestFailed;

  /// No description provided for @torChoiceConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected to Tor'**
  String get torChoiceConnected;

  /// No description provided for @connectionSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection Setup'**
  String get connectionSetupTitle;

  /// No description provided for @connectionSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter the address of your {type}.'**
  String connectionSetupDescription(String type);

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

  /// No description provided for @lwsSetupAddressHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 192.168.1.1:18090 or example.com:18090'**
  String get lwsSetupAddressHint;

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

  /// No description provided for @connectionProxyPortLabel.
  ///
  /// In en, this message translates to:
  /// **'HTTP Proxy Port'**
  String get connectionProxyPortLabel;

  /// No description provided for @connectionProxyPortHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get connectionProxyPortHint;

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

  /// No description provided for @connectionTestStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get connectionTestStop;

  /// No description provided for @connectionResultWorksTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection works'**
  String get connectionResultWorksTitle;

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

  /// No description provided for @connectionTestAgain.
  ///
  /// In en, this message translates to:
  /// **'Test again'**
  String get connectionTestAgain;

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

  /// No description provided for @fiatApiSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Fiat Display Setup'**
  String get fiatApiSetupTitle;

  /// No description provided for @fiatApiSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'An optional reference price beside your balances. Fetching it means talking to a rate server, so how that happens is up to you.'**
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
  /// **'Clearnet-Only'**
  String get fiatApiSettingsModeClearnet;

  /// No description provided for @fiatApiSettingsModeDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get fiatApiSettingsModeDisabled;

  /// No description provided for @fiatModeTorOnlyDesc.
  ///
  /// In en, this message translates to:
  /// **'Rates fetched over Tor · recommended'**
  String get fiatModeTorOnlyDesc;

  /// No description provided for @fiatModeClearnetDesc.
  ///
  /// In en, this message translates to:
  /// **'Not private — the rate server sees your IP address'**
  String get fiatModeClearnetDesc;

  /// No description provided for @fiatModeDisabledDesc.
  ///
  /// In en, this message translates to:
  /// **'No rates fetched, balances shown in crypto only'**
  String get fiatModeDisabledDesc;

  /// No description provided for @fiatApiSettingsDisplayCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Currency'**
  String get fiatApiSettingsDisplayCurrencyLabel;

  /// No description provided for @settingsFiatApiSettingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Fiat Display Settings'**
  String get settingsFiatApiSettingsLabel;

  /// No description provided for @fiatApiSettingsSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How rates are fetched, and the currency they are shown in.'**
  String get fiatApiSettingsSheetSubtitle;

  /// No description provided for @createWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'Start fresh, or restore?'**
  String get createWalletTitle;

  /// No description provided for @createWalletDescription.
  ///
  /// In en, this message translates to:
  /// **'One seed phrase covers all four chains. If you already have one, you can restore it now.'**
  String get createWalletDescription;

  /// No description provided for @createWalletRestoreExistingButton.
  ///
  /// In en, this message translates to:
  /// **'Restore from a seed'**
  String get createWalletRestoreExistingButton;

  /// No description provided for @createWalletRestoreExistingDesc.
  ///
  /// In en, this message translates to:
  /// **'Any BIP39 phrase'**
  String get createWalletRestoreExistingDesc;

  /// No description provided for @createWalletCreateNewButton.
  ///
  /// In en, this message translates to:
  /// **'Create a new wallet'**
  String get createWalletCreateNewButton;

  /// No description provided for @createWalletCreateNewDesc.
  ///
  /// In en, this message translates to:
  /// **'Spice Wallet generates a 15-word BIP39 seed'**
  String get createWalletCreateNewDesc;

  /// No description provided for @generateSeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Write these down, in order'**
  String get generateSeedTitle;

  /// No description provided for @generateSeedTitleCovered.
  ///
  /// In en, this message translates to:
  /// **'Your seed phrase'**
  String get generateSeedTitleCovered;

  /// No description provided for @generateSeedSubtitleCovered.
  ///
  /// In en, this message translates to:
  /// **'These fifteen words, in this order, are the wallet. Write them on paper — not in a photo or a notes app.'**
  String get generateSeedSubtitleCovered;

  /// No description provided for @generateSeedSubtitleRevealed.
  ///
  /// In en, this message translates to:
  /// **'Anyone with these words has your funds.'**
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

  /// No description provided for @generateSeedBirthdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Wallet birthday'**
  String get generateSeedBirthdayLabel;

  /// No description provided for @generateSeedBirthdayReason.
  ///
  /// In en, this message translates to:
  /// **'Where a future restore starts scanning'**
  String get generateSeedBirthdayReason;

  /// No description provided for @generateSeedConfirm.
  ///
  /// In en, this message translates to:
  /// **'I have written down all 15 words and stored them somewhere only I can reach.'**
  String get generateSeedConfirm;

  /// No description provided for @generateSeedContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get generateSeedContinueButton;

  /// No description provided for @lwsDetailsDescription.
  ///
  /// In en, this message translates to:
  /// **'You can use these details to whitelist this wallet on the light wallet server if needed.'**
  String get lwsDetailsDescription;

  /// No description provided for @restoreWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore wallet'**
  String get restoreWalletTitle;

  /// No description provided for @restoreWalletSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Any BIP39 phrase, from Spice Wallet or another wallet.'**
  String get restoreWalletSubtitle;

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

  /// No description provided for @restoreWalletScanFrom.
  ///
  /// In en, this message translates to:
  /// **'Scan from'**
  String get restoreWalletScanFrom;

  /// No description provided for @restoreWalletScanFromReason.
  ///
  /// In en, this message translates to:
  /// **'Earlier is slower but never misses funds.'**
  String get restoreWalletScanFromReason;

  /// No description provided for @restoreWalletNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get restoreWalletNotSet;

  /// No description provided for @restoreScanTitle.
  ///
  /// In en, this message translates to:
  /// **'When did this seed first hold funds?'**
  String get restoreScanTitle;

  /// No description provided for @restoreScanDescription.
  ///
  /// In en, this message translates to:
  /// **'For some assets, Spice Wallet only scans forward from this point. Guess early — a wrong-but-earlier answer costs sync time, a wrong-but-later one hides transactions.'**
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

  /// No description provided for @restoreWalletRestoreButton.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreWalletRestoreButton;

  /// No description provided for @navigationBarHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navigationBarHome;

  /// No description provided for @navigationBarSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navigationBarSettings;

  /// No description provided for @navigationBarHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navigationBarHistory;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @historyFilterBlockchain.
  ///
  /// In en, this message translates to:
  /// **'Blockchain'**
  String get historyFilterBlockchain;

  /// No description provided for @historyFilterAsset.
  ///
  /// In en, this message translates to:
  /// **'Asset'**
  String get historyFilterAsset;

  /// No description provided for @historyFilterType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get historyFilterType;

  /// No description provided for @historyTypeBridge.
  ///
  /// In en, this message translates to:
  /// **'Bridge'**
  String get historyTypeBridge;

  /// No description provided for @historyTypeSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get historyTypeSwap;

  /// No description provided for @historyTypeAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get historyTypeAdd;

  /// No description provided for @historyTypeRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get historyTypeRemove;

  /// No description provided for @historyFilterReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get historyFilterReset;

  /// No description provided for @unlockButton.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlockButton;

  /// No description provided for @unlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock wallet'**
  String get unlockReason;

  /// No description provided for @unlockUnableToAuthError.
  ///
  /// In en, this message translates to:
  /// **'Unable to authenticate.'**
  String get unlockUnableToAuthError;

  /// No description provided for @unlockLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Spice Wallet is locked'**
  String get unlockLockedTitle;

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

  /// No description provided for @homeSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get homeSyncing;

  /// No description provided for @homeSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get homeSynced;

  /// No description provided for @homeBlocksRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} blocks left'**
  String homeBlocksRemaining(String count);

  /// No description provided for @homeNoConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get homeNoConnection;

  /// No description provided for @homeCoinNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get homeCoinNotConfigured;

  /// No description provided for @homeAssetsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 asset} other{{count} assets}}'**
  String homeAssetsCount(int count);

  /// No description provided for @coinHomeAssetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get coinHomeAssetsTitle;

  /// No description provided for @coinHomeActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get coinHomeActivityTitle;

  /// No description provided for @coinHomeSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get coinHomeSwap;

  /// No description provided for @coinHomeSwapComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon!'**
  String get coinHomeSwapComingSoon;

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

  /// No description provided for @coinHomeAddExplorerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add an explorer to see history'**
  String get coinHomeAddExplorerTitle;

  /// No description provided for @coinHomeAddExplorerButton.
  ///
  /// In en, this message translates to:
  /// **'Add explorer'**
  String get coinHomeAddExplorerButton;

  /// No description provided for @homeFiatSource.
  ///
  /// In en, this message translates to:
  /// **'Kraken over Tor'**
  String get homeFiatSource;

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

  /// No description provided for @homeNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions'**
  String get homeNoTransactions;

  /// No description provided for @homeFiatApiError.
  ///
  /// In en, this message translates to:
  /// **'Error connecting to fiat API'**
  String get homeFiatApiError;

  /// No description provided for @homeTotalBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Balance'**
  String get homeTotalBalanceLabel;

  /// No description provided for @receiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receiveTitle;

  /// No description provided for @receivePrimaryAddressWarn.
  ///
  /// In en, this message translates to:
  /// **'Warning: Unless you know what you\'re doing, please consider using subaddresses for better privacy.'**
  String get receivePrimaryAddressWarn;

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

  /// No description provided for @sendContactsButton.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get sendContactsButton;

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

  /// No description provided for @sendInsufficientGasError.
  ///
  /// In en, this message translates to:
  /// **'Insufficient ETH to cover the network fee.'**
  String get sendInsufficientGasError;

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

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsSectionWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get settingsSectionWallet;

  /// No description provided for @settingsCoinConnectionSection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get settingsCoinConnectionSection;

  /// No description provided for @settingsCoinKeysSection.
  ///
  /// In en, this message translates to:
  /// **'Keys'**
  String get settingsCoinKeysSection;

  /// No description provided for @settingsCoinConnectionSetup.
  ///
  /// In en, this message translates to:
  /// **'Connection setup'**
  String get settingsCoinConnectionSetup;

  /// No description provided for @settingsCoinExplorer.
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get settingsCoinExplorer;

  /// No description provided for @settingsCoinNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get settingsCoinNotConfigured;

  /// No description provided for @settingsNotifyNewTxsLabel.
  ///
  /// In en, this message translates to:
  /// **'Notify New Transactions'**
  String get settingsNotifyNewTxsLabel;

  /// No description provided for @settingsNotifyNewTxsDescription.
  ///
  /// In en, this message translates to:
  /// **'Shows a notification when you receive a transaction. When connected to a Monero node, Background Sync must also be enabled.'**
  String get settingsNotifyNewTxsDescription;

  /// No description provided for @settingsNotifyNewTxsDescriptionIos.
  ///
  /// In en, this message translates to:
  /// **'Shows a notification when you receive a transaction.'**
  String get settingsNotifyNewTxsDescriptionIos;

  /// No description provided for @settingsBackgroundSyncLabel.
  ///
  /// In en, this message translates to:
  /// **'Background Sync'**
  String get settingsBackgroundSyncLabel;

  /// No description provided for @settingsBackgroundSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Periodically sync your wallets in the background so they\'re up to date when you open the app.'**
  String get settingsBackgroundSyncDescription;

  /// No description provided for @settingsForegroundSyncLabel.
  ///
  /// In en, this message translates to:
  /// **'Continuous Sync'**
  String get settingsForegroundSyncLabel;

  /// No description provided for @settingsForegroundSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep your wallets syncing continuously while the app runs in the background, with a persistent notification. Uses more battery.'**
  String get settingsForegroundSyncDescription;

  /// No description provided for @settingsAppLockLabel.
  ///
  /// In en, this message translates to:
  /// **'App Lock'**
  String get settingsAppLockLabel;

  /// No description provided for @settingsAppLockUnlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock wallet'**
  String get settingsAppLockUnlockReason;

  /// No description provided for @settingsAppLockUnableToAuthError.
  ///
  /// In en, this message translates to:
  /// **'Unable to authenticate. Make sure you have device unlock set up.'**
  String get settingsAppLockUnableToAuthError;

  /// No description provided for @settingsVerboseLoggingLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable Logging to File'**
  String get settingsVerboseLoggingLabel;

  /// No description provided for @settingsTestnetCoinsLabel.
  ///
  /// In en, this message translates to:
  /// **'Testnet Coins'**
  String get settingsTestnetCoinsLabel;

  /// No description provided for @settingsTestnetCoinsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show testnet coins (e.g. Bitcoin Testnet) in your coin list.'**
  String get settingsTestnetCoinsDescription;

  /// No description provided for @settingsVerboseLoggingDescription.
  ///
  /// In en, this message translates to:
  /// **'Logs wallet operations to a text file in the app\'s data folder for debugging purposes.'**
  String get settingsVerboseLoggingDescription;

  /// No description provided for @settingsVerboseLoggingDescriptionIos.
  ///
  /// In en, this message translates to:
  /// **'Logs wallet operations and allows the logs to be exported to a text file.'**
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
  /// **'Warm paper, the default'**
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
  /// **'Changes take effect straight away. Amount colours stay the same in both.'**
  String get settingsThemeSheetSubtitle;

  /// No description provided for @settingsLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageLabel;

  /// No description provided for @settingsLanguageSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Amounts and dates follow the language you pick.'**
  String get settingsLanguageSheetSubtitle;

  /// No description provided for @settingsSeedPhraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Seed phrase'**
  String get settingsSeedPhraseLabel;

  /// No description provided for @revealSeedSubtitleCovered.
  ///
  /// In en, this message translates to:
  /// **'The same fifteen words this wallet was created with, in the same order.'**
  String get revealSeedSubtitleCovered;

  /// No description provided for @revealSeedSubtitleRevealed.
  ///
  /// In en, this message translates to:
  /// **'Anyone holding these words holds the wallet. No support agent will ever ask you for them.'**
  String get revealSeedSubtitleRevealed;

  /// No description provided for @revealSeedBackButton.
  ///
  /// In en, this message translates to:
  /// **'Back to settings'**
  String get revealSeedBackButton;

  /// No description provided for @revealSeedHideButton.
  ///
  /// In en, this message translates to:
  /// **'Hide and go back'**
  String get revealSeedHideButton;

  /// No description provided for @revealSeedAuthReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you to view your seed phrase'**
  String get revealSeedAuthReason;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @settingsLwsViewKeysButton.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get settingsLwsViewKeysButton;

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

  /// No description provided for @txDetailsCopyHint.
  ///
  /// In en, this message translates to:
  /// **'tap any value to copy'**
  String get txDetailsCopyHint;

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

  /// No description provided for @txDetailsChangeRecipientLabel.
  ///
  /// In en, this message translates to:
  /// **'Change Recipient'**
  String get txDetailsChangeRecipientLabel;

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
  /// **'Screenshots are blocked on this screen. The view key lets a server see everything you receive — share it only with a server you run or trust.'**
  String get lwsKeysWarning;

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
  /// **'No contacts yet'**
  String get addressBookNoContacts;

  /// No description provided for @addressBookNoContactsDescription.
  ///
  /// In en, this message translates to:
  /// **'Add your first contact by tapping the + button'**
  String get addressBookNoContactsDescription;

  /// No description provided for @addressBookNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No contacts found'**
  String get addressBookNoSearchResults;

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

  /// No description provided for @addressBookAddDescription.
  ///
  /// In en, this message translates to:
  /// **'A name, and at least one address to pay them on.'**
  String get addressBookAddDescription;

  /// No description provided for @addressBookEditDescription.
  ///
  /// In en, this message translates to:
  /// **'Addresses get pasted or scanned, not typed. At least one is required.'**
  String get addressBookEditDescription;

  /// No description provided for @addressBookAddressesLabel.
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get addressBookAddressesLabel;

  /// No description provided for @addressBookAddressesNoneYet.
  ///
  /// In en, this message translates to:
  /// **'none yet'**
  String get addressBookAddressesNoneYet;

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

  /// No description provided for @addressBookAtLeastOneAddressError.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one address'**
  String get addressBookAtLeastOneAddressError;

  /// No description provided for @addressBookNoContactsForCoin.
  ///
  /// In en, this message translates to:
  /// **'No contacts with a {coinSymbol} address'**
  String addressBookNoContactsForCoin(String coinSymbol);

  /// No description provided for @invalidAddressForCoin.
  ///
  /// In en, this message translates to:
  /// **'Invalid {coin} address'**
  String invalidAddressForCoin(String coin);

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

  /// No description provided for @sendFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get sendFromLabel;

  /// No description provided for @sendToLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get sendToLabel;

  /// No description provided for @sendPriorityHeading.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get sendPriorityHeading;

  /// No description provided for @sendAvailableSuffix.
  ///
  /// In en, this message translates to:
  /// **'available'**
  String get sendAvailableSuffix;

  /// No description provided for @sendNetworkFee.
  ///
  /// In en, this message translates to:
  /// **'Network fee'**
  String get sendNetworkFee;

  /// No description provided for @sendMaxButton.
  ///
  /// In en, this message translates to:
  /// **'MAX'**
  String get sendMaxButton;

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

  /// No description provided for @sendAddressHint.
  ///
  /// In en, this message translates to:
  /// **'{coin} address'**
  String sendAddressHint(String coin);

  /// No description provided for @sendPickContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Send to a contact'**
  String get sendPickContactTitle;

  /// No description provided for @sendPickContactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a contact with a {coin} address.'**
  String sendPickContactSubtitle(String coin);

  /// No description provided for @sendContactNoAddress.
  ///
  /// In en, this message translates to:
  /// **'No {coin} address'**
  String sendContactNoAddress(String coin);

  /// No description provided for @sendFailedToGetFeesError.
  ///
  /// In en, this message translates to:
  /// **'Failed to get fees.'**
  String get sendFailedToGetFeesError;

  /// No description provided for @torSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tor Settings'**
  String get torSettingsTitle;

  /// No description provided for @torSettingsSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How Spice Wallet reaches the network. Changing this reconnects every chain.'**
  String get torSettingsSheetSubtitle;

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

  /// No description provided for @torSettingsSocksPortLabel.
  ///
  /// In en, this message translates to:
  /// **'SOCKS Port'**
  String get torSettingsSocksPortLabel;

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

  /// No description provided for @settingsTorSettingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tor Settings'**
  String get settingsTorSettingsLabel;

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

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @explorerSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Block Explorer Setup'**
  String get explorerSetupTitle;

  /// No description provided for @explorerSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'Optionally set a Blockscout instance to load full transaction history. Leave empty to disable — future sent transactions still appear without it.'**
  String get explorerSetupDescription;

  /// No description provided for @explorerAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Explorer Address'**
  String get explorerAddressLabel;

  /// No description provided for @explorerRemovedMessage.
  ///
  /// In en, this message translates to:
  /// **'Explorer removed.'**
  String get explorerRemovedMessage;
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
