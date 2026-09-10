// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get continueText => 'Continue';

  @override
  String get cancel => 'Cancel';

  @override
  String get done => 'Done';

  @override
  String get close => 'Close';

  @override
  String get unknownError => 'Unknown error.';

  @override
  String get warning => 'Warning';

  @override
  String get amount => 'Amount';

  @override
  String get networkFee => 'Network Fee';

  @override
  String get address => 'Address';

  @override
  String get pending => 'Pending';

  @override
  String get copy => 'Copy';

  @override
  String get addressCopied => 'Address copied to clipboard';

  @override
  String get fieldEmptyError => 'This field cannot be empty.';

  @override
  String get welcomeTitle => 'Welcome!';

  @override
  String get welcomeDescription =>
      'Skylight Wallet is one of the simplest Monero wallets. We will help you set up a wallet and connect to a server.';

  @override
  String get welcomeGetStarted => 'Get Started';

  @override
  String get welcomeAgreePrefix => 'By continuing you agree to the ';

  @override
  String get welcomeTermsLink => 'Terms of Service';

  @override
  String get welcomeAgreeMiddle => ' and ';

  @override
  String get welcomePrivacyLink => 'Privacy Policy';

  @override
  String get restoreWarningTitle => 'Restore Warning';

  @override
  String get restoreWarningDescription =>
      'Are you sure? The server that you connect to will be able to see your past and future Monero transaction history.';

  @override
  String get restoreWarningContinueButton => 'Continue';

  @override
  String get lwsSetupTitle => 'Connection Setup';

  @override
  String get lwsSetupDescription =>
      'Connect to a Monero light-wallet server (LWS) or your own full node.';

  @override
  String get lwsSetupAddressHint => 'e.g. 192.168.1.1:18090 or example.com:18090';

  @override
  String get lwsSetupProxyPortLabel => 'HTTP Proxy Port (Optional)';

  @override
  String get lwsSetupProxyPortHint => 'e.g. 4444 for I2P';

  @override
  String get lwsSetupUseTorLabel => 'Use Tor';

  @override
  String get lwsSetupTestConnectionButton => 'Test Connection';

  @override
  String get lwsSetupStartingTor => 'Starting Tor...';

  @override
  String get lwsSetupContinueButton => 'Continue';

  @override
  String get connectionTypeLws => 'Light Wallet Server';

  @override
  String get connectionTypeNode => 'Monero Node';

  @override
  String get connectionNodeAddressHint => 'e.g. node.example.com:18081';

  @override
  String get connectionRemoteIpNotAllowed =>
      'Connections to remote IP addresses aren\'t allowed. Use a domain name or a local IP address.';

  @override
  String get connectionProtocolHttps => 'Removing protocol. Using HTTPS for domains.';

  @override
  String get connectionProtocolHttp => 'Removing protocol. Using HTTP for local addresses.';

  @override
  String get connectionTestStop => 'Stop';

  @override
  String get connectionTestingTitle => 'Testing connection';

  @override
  String get connectionTestingDetail => 'Checking whether the server answers.';

  @override
  String get connectionTestAgain => 'Test again';

  @override
  String get connectionResultWorksTitle => 'Connection works';

  @override
  String get connectionResultFailedTitle => 'Could not reach this server';

  @override
  String get connectionResultFailedDetail =>
      'Nothing answered. Check the address and port, and whether the server accepts your connection.';

  @override
  String get connectionReachedOverTor => 'Reached over Tor';

  @override
  String get connectionReachedViaProxy => 'Reached through your proxy';

  @override
  String get connectionReachedDirect => 'Reached directly';

  @override
  String get connectionIndicatorHttps => 'HTTPS';

  @override
  String get connectionIndicatorLocal => 'Local';

  @override
  String get connectionIndicatorTorInternal => 'Internal Tor';

  @override
  String connectionIndicatorTorExternal(String port) {
    return 'Using Port $port';
  }

  @override
  String get settingsConnectionSettingsLabel => 'Connection Settings';

  @override
  String get settingsConnectionServerLws => 'LWS';

  @override
  String get settingsConnectionServerNode => 'Node';

  @override
  String get settingsConnectionOverTor => 'over Tor';

  @override
  String get settingsConnectionOverClearnet => 'over Clearnet';

  @override
  String get settingsConnectionInLocalNetwork => 'in Local Network';

  @override
  String get settingsBackgroundSyncLabel => 'Background Sync';

  @override
  String get settingsBackgroundSyncDescription =>
      'Periodically sync Monero in the background so it\'s up to date when you open the app. Only runs while charging and on WiFi.';

  @override
  String get settingsForegroundSyncLabel => 'Continuous Sync';

  @override
  String get settingsForegroundSyncDescription =>
      'Keep Monero syncing continuously while the app runs in the background, with a persistent notification. Uses more battery.';

  @override
  String homeBlocksRemaining(String count) {
    return '$count blocks left';
  }

  @override
  String get fiatApiSetupTitle => 'Fiat Display Setup';

  @override
  String get fiatApiSetupDescription => 'Optional reference price for your XMR balance.';

  @override
  String get fiatApiSettingsModeLabel => 'Mode';

  @override
  String get fiatApiSettingsModeTorOnly => 'Tor-Only';

  @override
  String get fiatApiSettingsModeClearnet => 'Clearnet-Only (Not Private)';

  @override
  String get fiatApiSettingsModeDisabled => 'Disabled';

  @override
  String get fiatModeTorOnlyDesc => 'Rates fetched over Tor · recommended';

  @override
  String get fiatModeClearnetDesc => 'Not private — the rate server sees your IP address';

  @override
  String get fiatModeDisabledDesc => 'No rates fetched, balances shown in crypto only';

  @override
  String get fiatApiSettingsDisplayCurrencyLabel => 'Display Currency';

  @override
  String get createWalletTitle => 'Create Wallet';

  @override
  String get createWalletDescription =>
      'Do you already have a Monero wallet seed, or do you need to make a new one?';

  @override
  String get createWalletRestoreExistingButton => 'Restore Existing';

  @override
  String get createWalletRestoreExistingDesc => 'Enter an existing Monero seed';

  @override
  String get createWalletCreateNewButton => 'Create New';

  @override
  String get createWalletCreateNewDesc => 'Skylight Wallet generates a new polyseed';

  @override
  String get createWalletPasswordTitle => 'Create Wallet Password';

  @override
  String get createWalletPasswordDescription =>
      'Create a password to protect your wallet. This password will be required to unlock your wallet.';

  @override
  String get createWalletPasswordHint => 'Enter your password';

  @override
  String get createWalletConfirmPasswordHint => 'Confirm your password';

  @override
  String get passwordTooShortError => 'Password must be at least 8 characters long.';

  @override
  String get passwordsDoNotMatchError => 'Passwords do not match.';

  @override
  String get generateSeedTitle => 'Write these down, in order';

  @override
  String get generateSeedTitleCovered => 'Your seed phrase';

  @override
  String get generateSeedDescription =>
      'This is your polyseed. Write it down and keep it in a safe place.';

  @override
  String get generateSeedSubtitleCovered =>
      'These words, in this order, are your wallet. Write them on paper — not in a photo or a notes app.';

  @override
  String get generateSeedSubtitleRevealed => 'Anyone with these words has your funds.';

  @override
  String get generateSeedScreenshotNote =>
      'Screenshots are blocked on this screen. Make sure nobody is looking over your shoulder.';

  @override
  String get generateSeedReveal => 'Tap to reveal';

  @override
  String get generateSeedConfirm =>
      'I have written down all the words and stored them somewhere only I can reach.';

  @override
  String get generateSeedContinueButton => 'I Wrote It Down';

  @override
  String get lwsDetailsTitle => 'Wallet Details';

  @override
  String get lwsDetailsDescription =>
      'You can use these details to whitelist this wallet on the light wallet server if needed.';

  @override
  String get lwsDetailsPrimaryAddressLabel => 'Primary Address';

  @override
  String get lwsDetailsSecretViewKeyLabel => 'Secret View Key';

  @override
  String get lwsDetailsRestoreHeightLabel => 'Restore Height';

  @override
  String get restoreWalletTitle => 'Restore Wallet';

  @override
  String get restoreWalletDescription =>
      'Input your Monero seed below. We will check common formats.';

  @override
  String get restoreWalletSeedLabel => 'Seed';

  @override
  String get restoreWalletRestoreHeightLabel => 'Restore Height (optional)';

  @override
  String get restoreWalletRestoreDateLabel => 'Restore Date (optional)';

  @override
  String get restoreWalletScanFrom => 'Scan from';

  @override
  String get restoreWalletScanFromReason => 'Earlier is slower but never misses funds.';

  @override
  String get restoreWalletNotSet => 'Not set';

  @override
  String get restoreScanTitle => 'When did this seed first hold funds?';

  @override
  String get restoreScanDescription =>
      'Skylight Wallet only scans forward from this point. Guess early — a wrong-but-earlier answer costs sync time, a wrong-but-later one hides transactions.';

  @override
  String get restoreScanPickMonth => 'Pick a month';

  @override
  String get restoreScanNotSure => 'I\'m not sure';

  @override
  String get restoreScanNotSureDesc =>
      'Scan everything. Slower this first setup but not any slower later. Always complete.';

  @override
  String get restoreScanFromStart => 'Genesis';

  @override
  String get restoreScanDone => 'Done';

  @override
  String get restoreWalletRestoreButton => 'Restore';

  @override
  String get restoreWalletInvalidMnemonic => 'Invalid seed.';

  @override
  String get restoreWalletSeedLength => 'Seed length';

  @override
  String get restoreWalletPaste => 'Paste';

  @override
  String get restoreWalletSeedTypePolyseed => 'Polyseed';

  @override
  String get restoreWalletSeedTypeBip39 => 'BIP39';

  @override
  String get restoreWalletSeedTypeLegacy => 'Legacy';

  @override
  String restoreWalletBadWord(int position) {
    return 'Word $position isn\'t a BIP39 word.';
  }

  @override
  String restoreWalletDidYouMean(String word) {
    return 'Did you mean $word?';
  }

  @override
  String get restoreWalletChecksumError =>
      'This isn\'t a valid seed phrase — check the words and their order.';

  @override
  String get navigationBarWallet => 'Wallet';

  @override
  String get navigationBarSettings => 'Settings';

  @override
  String get unlockButton => 'Unlock';

  @override
  String get unlockReason => 'Unlock Wallet';

  @override
  String get unlockUnableToAuthError => 'Unable to authenticate.';

  @override
  String get unlockTitle => 'Unlock Wallet';

  @override
  String get unlockDescription => 'Enter your wallet password to unlock';

  @override
  String get unlockPasswordLabel => 'Password';

  @override
  String get unlockPasswordHint => 'Enter your password';

  @override
  String get unlockIncorrectPasswordError => 'Incorrect password. Please try again.';

  @override
  String get homeConnecting => 'Connecting';

  @override
  String get homeSyncing => 'Syncing';

  @override
  String get homeHeight => 'Height';

  @override
  String get homeReceive => 'Receive';

  @override
  String get homeSend => 'Send';

  @override
  String get homeBalanceLocked => 'Locked';

  @override
  String get homeTransactionsTitle => 'Transactions';

  @override
  String get homeOutgoingTxSemanticLabel => 'Outgoing Transaction';

  @override
  String get homeIncomingTxSemanticLabel => 'Incoming Transaction';

  @override
  String get homeTransactionConfirmed => 'Confirmed';

  @override
  String get homeNoTransactions => 'No Transactions';

  @override
  String get homeFiatApiError => 'Error connecting to fiat API';

  @override
  String get homeDisconnected => 'Disconnected';

  @override
  String get coinHomeActivityTitle => 'Activity';

  @override
  String get coinHomeReceived => 'Received';

  @override
  String get coinHomeSent => 'Sent';

  @override
  String get receiveTitle => 'Receive';

  @override
  String get receivePrimaryAddressWarn =>
      'Warning: Unless you know what you\'re doing, please consider using subaddresses for better privacy.';

  @override
  String get receiveShareButton => 'Share';

  @override
  String get receiveShowSubaddressButton => 'Show Subaddress';

  @override
  String get receiveShowPrimaryAddressButton => 'Show Primary Address';

  @override
  String get receiveServerNoSubaddressesWarn =>
      'Warning: This server does not support subaddresses. For better privacy, consider using a server that supports them. You are receiving to your primary address.';

  @override
  String get receiveMaxSubaddressesReachedWarn =>
      'You have reached the maximum number of subaddresses supported by this server. This is a used address.';

  @override
  String get receiveSubaddressTab => 'Subaddress';

  @override
  String get receivePrimaryTab => 'Primary address';

  @override
  String get receiveCopyAddress => 'Copy address';

  @override
  String receiveAddressHeading(String coin) {
    return 'Your $coin address';
  }

  @override
  String receiveBlockchainSubtitle(String coin) {
    return '$coin blockchain';
  }

  @override
  String get sendTitle => 'Send';

  @override
  String get sendSendButton => 'Send';

  @override
  String get sendTransactionSuccessfullySent => 'Transaction successfully sent!';

  @override
  String get sendOpenAliasResolveError => 'Invalid OpenAlias.';

  @override
  String get sendInvalidAddressError => 'Invalid address.';

  @override
  String get sendInsufficientBalanceError => 'Insufficient balance.';

  @override
  String get sendInsufficientBalanceToCoverFeeError =>
      'Insufficient balance to cover the network fee.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionBehaviour => 'Behaviour';

  @override
  String get settingsSectionWallet => 'Wallet';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsNotifyNewTxsLabel => 'Notify New Transactions';

  @override
  String get settingsNotifyNewTxsDescription =>
      'Shows a notification when you receive a transaction. When connected to a Monero node, Background Sync must also be enabled.';

  @override
  String get settingsNotifyNewTxsDescriptionIos =>
      'Notifications will be delayed for Tor LWS connections.';

  @override
  String get settingsAppLockLabel => 'App Lock';

  @override
  String get settingsAppLockUnlockReason => 'Unlock Wallet';

  @override
  String get settingsAppLockUnableToAuthError =>
      'Unable to authenticate. Make sure you have device unlock set up.';

  @override
  String get settingsVerboseLoggingLabel => 'Enable Logging to File';

  @override
  String get settingsVerboseLoggingDescription =>
      'Logs wallet operations to a text file in the app\'s data folder for debugging purposes.';

  @override
  String get settingsVerboseLoggingDescriptionIos =>
      'Logs wallet operations and allows the logs to be exported to a text file.';

  @override
  String get settingsExportLogsLabel => 'Export Logs';

  @override
  String get settingsExportLogsButton => 'Export';

  @override
  String get settingsExportLogsError => 'No logs found to export.';

  @override
  String get settingsThemeLabel => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeLightDesc => 'Light and clean';

  @override
  String get settingsThemeDarkDesc => 'Dark ground, easier at night';

  @override
  String get settingsThemeSystemDesc => 'Follows your phone';

  @override
  String get settingsThemeSheetSubtitle =>
      'Changes take effect straight away. Amount colours stay the same in both.';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get settingsLanguageSheetSubtitle => 'Amounts and dates follow the language you pick.';

  @override
  String get settingsFiatApiSettingsLabel => 'Fiat Display Settings';

  @override
  String get settingsLwsViewKeysLabel => 'LWS View Keys';

  @override
  String get settingsLwsViewKeysButton => 'View';

  @override
  String get settingsSecretKeysLabel => 'Secret Restore Keys';

  @override
  String get settingsSecretKeysButton => 'View';

  @override
  String get settingsViewLwsKeysDialogText =>
      'Only share this information with your light-wallet server. These keys allow the holder to permanently see all transactions related to your wallets. Sharing these with an untrusted person will significantly harm your privacy.';

  @override
  String get settingsViewLwsKeysDialogRevealButton => 'Reveal';

  @override
  String get settingsViewSecretKeysDialogText =>
      'Do not share these keys with anyone, including anyone claiming to be support. If you receive a request to provide these, you are being scammed. If you provide this information to another person, you will lose your money and it cannot be recovered.';

  @override
  String get settingsViewSecretKeysDialogRevealButton => 'Reveal';

  @override
  String get settingsDeleteWalletButton => 'Delete Wallet';

  @override
  String get settingsDeleteWalletDialogText =>
      'Are you sure you want to delete your wallet? You will lose access to your funds unless you have backed up your seed phrase.';

  @override
  String get settingsDeleteWalletDialogDeleteButton => 'Delete';

  @override
  String get txDetailsTitle => 'Transaction Details';

  @override
  String get txDetailsHashLabel => 'Hash';

  @override
  String get txDetailsTimeAndDateLabel => 'Time and Date';

  @override
  String get txDetailsConfirmationHeightLabel => 'Confirmation Height';

  @override
  String get txDetailsConfirmationsLabel => 'Confirmations';

  @override
  String get txDetailsViewKeyLabel => 'View Key';

  @override
  String get txDetailsRecipientsLabel => 'Recipients';

  @override
  String get txDetailsChangeRecipientLabel => 'Change';

  @override
  String get txDetailsCopyHint => 'tap any value to copy';

  @override
  String get txDetailsFailed => 'This transaction failed. The funds were not sent.';

  @override
  String get txDetailsUnknownStatus =>
      'This transaction was not confirmed as sent. Check before sending again.';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get lwsKeysTitle => 'LWS Keys';

  @override
  String get lwsKeysPrimaryAddress => 'Primary Address';

  @override
  String get lwsKeysRestoreHeight => 'Restore Height';

  @override
  String get lwsKeysSecretViewKey => 'Secret View Key';

  @override
  String get lwsKeysWarning =>
      'Screenshots are blocked on this screen. The view key lets a server see everything you receive — share it only with a server you run or trust.';

  @override
  String get secretKeysTitle => 'Secret Restore Keys';

  @override
  String get secretKeysDescription =>
      'These seeds and keys restore full control of your wallet. Anyone who sees them can spend your funds.';

  @override
  String get secretKeysMnemonic => 'Seed';

  @override
  String get secretKeysPublicSpendKey => 'Public Spend Key';

  @override
  String get secretKeysSecretSpendKey => 'Secret Spend Key';

  @override
  String get secretKeysPublicViewKey => 'Public View Key';

  @override
  String get secretKeysWarning =>
      'Never share these or enter them into any website. Store them offline.';

  @override
  String get scanQrTitle => 'Scan QR Code';

  @override
  String get confirmSendTitle => 'Confirm Send';

  @override
  String get confirmSendDescription =>
      'Transactions are irreversible, so make sure that these details match exactly.';

  @override
  String confirmSendHighFeeWarning(String percent) {
    return 'The network fee is $percent of the amount you are sending.';
  }

  @override
  String get addressBookTitle => 'Address Book';

  @override
  String get addressBookAddContact => 'Add Contact';

  @override
  String get addressBookEditContact => 'Edit Contact';

  @override
  String get addressBookDeleteContact => 'Delete Contact';

  @override
  String addressBookDeleteContactConfirmation(String contactName) {
    return 'Are you sure you want to delete \"$contactName\"?';
  }

  @override
  String get addressBookDelete => 'Delete';

  @override
  String get addressBookSearchHint => 'Search contacts...';

  @override
  String get addressBookNoContacts => 'No Contacts Yet';

  @override
  String get addressBookNoContactsDescription => 'Add your first contact by tapping the + button';

  @override
  String get addressBookNoSearchResults => 'No Contacts Found';

  @override
  String get addressBookCopyAddress => 'Copy Address';

  @override
  String get addressBookEdit => 'Edit';

  @override
  String get addressBookContactName => 'Contact Name';

  @override
  String get addressBookNameHint => 'Name';

  @override
  String get addressBookAddressHint => 'Monero address';

  @override
  String get addressBookAddDescription => 'A name and a Monero address to pay them on.';

  @override
  String get addressBookEditDescription => 'Update this contact\'s name or address.';

  @override
  String get addressBookUpdate => 'Update';

  @override
  String get addressBookSave => 'Save';

  @override
  String get sendSelectedContact => 'Selected Contact';

  @override
  String get sendClearSelectedContact => 'Clear Selected Contact';

  @override
  String get sendPriorityLow => 'Low';

  @override
  String get sendPriorityNormal => 'Normal';

  @override
  String get sendPriorityHigh => 'High';

  @override
  String get sendPriorityLabel => 'Priority';

  @override
  String get sendTransactionPriority => 'Transaction Priority';

  @override
  String get sendFeeLabel => 'Fee';

  @override
  String get sendContactsButton => 'Contacts';

  @override
  String get sendToLabel => 'To';

  @override
  String get sendPasteButton => 'Paste';

  @override
  String get sendScanButton => 'Scan';

  @override
  String get sendMaxButton => 'MAX';

  @override
  String get sendNetworkFee => 'Network fee';

  @override
  String get sendPriorityHeading => 'Priority';

  @override
  String get sendPickContactTitle => 'Send to a contact';

  @override
  String get sendAvailableSuffix => 'available';

  @override
  String get sendFailedToGetFeesError => 'Failed to get fees.';

  @override
  String get torInfoTitle => 'Tor Built-in';

  @override
  String get torInfoDescription =>
      'Skylight Wallet automatically uses built-in Tor to protect your internet connections.';

  @override
  String get torInfoContinueButton => 'Continue';

  @override
  String get torInfoConfigureButton => 'Configure';

  @override
  String get torSettingsTitle => 'Tor Settings';

  @override
  String get torSettingsModeLabel => 'Tor Mode';

  @override
  String get torSettingsModeBuiltIn => 'Built-in Tor';

  @override
  String get torSettingsModeExternal => 'External Tor';

  @override
  String get torSettingsModeDisabled => 'No Tor';

  @override
  String get torChoiceBuiltInDesc => 'Bundled with Skylight Wallet · recommended';

  @override
  String get torChoiceExternalDesc => 'Orbot, or a daemon you run yourself';

  @override
  String get torChoiceNoTorDesc => 'Servers you connect to can see your IP address';

  @override
  String get torChoiceConnected => 'Connected to Tor';

  @override
  String get torChoiceTestFailed => 'Test failed';

  @override
  String get torChoiceTitle => 'How should Skylight Wallet reach the network?';

  @override
  String get torChoiceSubtitle =>
      'Nothing connects until you choose. Tor hides your IP address from the servers Skylight Wallet talks to.';

  @override
  String get torSettingsSocksPortLabel => 'SOCKS Port';

  @override
  String get torSettingsSocksPortHint => 'e.g. 9050';

  @override
  String get torSettingsUseOrbotLabel => 'Use Orbot/InviZible';

  @override
  String get torSettingsUseOrbotLabelIos => 'Use Orbot';

  @override
  String get torSettingsSaveButton => 'Save';

  @override
  String get torSettingsTestConnectionButton => 'Test Connection';

  @override
  String get torDisabledWalletsWarningTitle => 'Disable Tor?';

  @override
  String get torDisabledWalletsWarningBody =>
      'Some wallets are set to connect over Tor. Disabling Tor will disconnect them, and they will stay disconnected until you reconfigure their connection.';

  @override
  String get torDisabledWalletsWarningConfirm => 'Disable Tor';

  @override
  String get settingsTorSettingsLabel => 'Tor Settings';

  @override
  String get lwsSetupUsingInternalTor => 'Using Internal Tor';

  @override
  String lwsSetupUsingExternalTor(String address) {
    return 'Using External Tor Proxy at $address';
  }

  @override
  String get lwsSetupTorDisabledError => 'Tor is disabled. Please go back and enable it.';

  @override
  String get lwsSetupInvalidQrCode => 'Invalid connection address.';
}
