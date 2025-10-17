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
  /// **'Skylight is one of the simplest Monero wallets. We will help you set up a wallet and connect to a server.'**
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

  /// No description provided for @connectionSetupAddressHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 192.168.1.1:18090 or example.com:18090'**
  String get connectionSetupAddressHint;

  /// No description provided for @connectionSetupProxyPortLabel.
  ///
  /// In en, this message translates to:
  /// **'HTTP Proxy Port (optional)'**
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

  /// No description provided for @lwsDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet Details'**
  String get lwsDetailsTitle;

  /// No description provided for @lwsDetailsDescription.
  ///
  /// In en, this message translates to:
  /// **'You can use these details to whitelist this wallet on the light wallet server if needed.'**
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
  /// **'Restore Height'**
  String get restoreWalletRestoreHeightLabel;

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

  /// No description provided for @navigationBarKeys.
  ///
  /// In en, this message translates to:
  /// **'Keys'**
  String get navigationBarKeys;

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
  /// **'locked'**
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
  /// **'No transactions'**
  String get homeNoTransactions;

  /// No description provided for @receiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receiveTitle;

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

  /// No description provided for @settingsNotifyNewTxsLabel.
  ///
  /// In en, this message translates to:
  /// **'Notify New Transactions'**
  String get settingsNotifyNewTxsLabel;

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
  /// **'Unable to authenticate.'**
  String get settingsAppLockUnableToAuthError;

  /// No description provided for @settingsVerboseLoggingLabel.
  ///
  /// In en, this message translates to:
  /// **'Verbose Logging'**
  String get settingsVerboseLoggingLabel;

  /// No description provided for @settingsVerboseLoggingDescription.
  ///
  /// In en, this message translates to:
  /// **'Logs wallet operations to a text file in the app\'s data folder for debugging purposes.'**
  String get settingsVerboseLoggingDescription;

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

  /// No description provided for @settingsLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageLabel;

  /// No description provided for @settingsDisplayCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Currency'**
  String get settingsDisplayCurrencyLabel;

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
  /// **'Only share this information with your LWS server. These keys allow the holder to permanently see all transactions related to your wallets. Sharing these with an untrusted person will significantly harm your privacy.'**
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
  /// **'Transaction'**
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

  /// No description provided for @secretKeysTitle.
  ///
  /// In en, this message translates to:
  /// **'Secret Restore Keys'**
  String get secretKeysTitle;

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

  /// No description provided for @addressBookAddressCopied.
  ///
  /// In en, this message translates to:
  /// **'Address copied to clipboard'**
  String get addressBookAddressCopied;

  /// No description provided for @sendSelectFromAddressBook.
  ///
  /// In en, this message translates to:
  /// **'Select from Address Book'**
  String get sendSelectFromAddressBook;

  /// No description provided for @sendSelectedContact.
  ///
  /// In en, this message translates to:
  /// **'Selected contact'**
  String get sendSelectedContact;

  /// No description provided for @sendClearSelectedContact.
  ///
  /// In en, this message translates to:
  /// **'Clear selected contact'**
  String get sendClearSelectedContact;

  /// No description provided for @sendEditAddress.
  ///
  /// In en, this message translates to:
  /// **'Edit Address'**
  String get sendEditAddress;
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
