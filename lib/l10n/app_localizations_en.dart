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
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get fieldEmptyError => 'This field cannot be empty.';

  @override
  String get welcomeDescription =>
      'A simple, open-source, and modern self-custody wallet for Serai and the blockchain networks that Serai supports: Bitcoin, Ethereum, and Monero. You are in total control. Maintained by MAGIC Grants, a public charity.';

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
  String get torChoiceTitle => 'Tor Connection Setup';

  @override
  String get torChoiceSubtitle =>
      'Tor can hide your IP address from servers you connect to. This does not reduce the information that is stored on public blockchains. You can enable or disable Tor for each connection individually. In general, how do you want Spice Wallet to handle Tor connections?';

  @override
  String get torChoiceBuiltInDesc => 'Bundled with Spice Wallet · recommended';

  @override
  String get torChoiceExternalDesc => 'Orbot, or a daemon you run yourself';

  @override
  String get torChoiceNoTorDesc => 'Servers you connect to can see your IP address';

  @override
  String get torChoiceOrbot => 'Use Orbot (port 9050)';

  @override
  String get torChoiceTestFailed => 'Test failed';

  @override
  String get torChoiceConnected => 'Connected to Tor';

  @override
  String get connectionSetupTitle => 'Connection Setup';

  @override
  String connectionSetupDescription(String type) {
    return 'Enter the address of your $type. Only select a server you trust. Even if you use Tor, this server can learn information about you.';
  }

  @override
  String connectionSetupDescriptionLws(String type) {
    return 'Enter the address of your $type. Only select a server you trust. Even if you use Tor, this server can learn information about you. Your private view key and primary address will be shared with this server.';
  }

  @override
  String get connectionTypeLws => 'Light Wallet Server';

  @override
  String get connectionTypeNode => 'Monero Node';

  @override
  String get lwsSetupAddressHint => 'e.g. 192.168.1.1:18090 or example.com:18090';

  @override
  String get lwsSetupUseTorLabel => 'Use Tor';

  @override
  String get lwsSetupTestConnectionButton => 'Test Connection';

  @override
  String get connectionProxyPortLabel => 'HTTP Proxy Port';

  @override
  String get connectionProxyPortHint => 'Optional';

  @override
  String get connectionTestingTitle => 'Testing connection';

  @override
  String get connectionTestingDetail => 'Checking whether the server answers.';

  @override
  String get connectionTestStop => 'Stop';

  @override
  String get connectionResultWorksTitle => 'Connection works';

  @override
  String get connectionReachedOverTor => 'Reached over Tor';

  @override
  String get connectionReachedViaProxy => 'Reached through your proxy';

  @override
  String get connectionReachedDirect => 'Reached directly';

  @override
  String get connectionResultFailedTitle => 'Could not reach this server';

  @override
  String get connectionResultFailedDetail =>
      'Nothing answered. Check the address and port, and whether the server accepts your connection.';

  @override
  String get connectionTestAgain => 'Test again';

  @override
  String get lwsSetupStartingTor => 'Starting Tor...';

  @override
  String get lwsSetupContinueButton => 'Continue';

  @override
  String get fiatApiSetupTitle => 'Price Display Setup';

  @override
  String get fiatApiSetupDescription =>
      'Spice Wallet can automatically fetch the latest asset prices. Your balances are not sent to the server. How do you want to fetch this price data?';

  @override
  String get fiatApiSettingsModeLabel => 'Mode';

  @override
  String get fiatApiSettingsModeTorOnly => 'Tor-Only';

  @override
  String get fiatApiSettingsModeClearnet => 'Clearnet-Only';

  @override
  String get fiatApiSettingsModeDisabled => 'Disabled';

  @override
  String get fiatModeTorOnlyDesc => 'Prices fetched over Tor · recommended';

  @override
  String get fiatModeClearnetDesc => 'Not private, the price server sees your IP address';

  @override
  String get fiatModeDisabledDesc => 'No prices fetched, balances shown in crypto only';

  @override
  String get fiatApiSettingsDisplayCurrencyLabel => 'Display Currency';

  @override
  String get settingsFiatApiSettingsLabel => 'Price Display Settings';

  @override
  String get fiatApiSettingsSheetSubtitle =>
      'How prices are fetched, and the currency they are shown in.';

  @override
  String get createWalletTitle => 'Wallet Setup';

  @override
  String get createWalletDescription =>
      'A single seed phrase secures access to your wallet across all blockchain networks. Would you like to create a new wallet or restore an existing wallet?';

  @override
  String get createWalletRestoreExistingButton => 'Restore from a seed';

  @override
  String get createWalletRestoreExistingDesc => 'Any BIP39 phrase';

  @override
  String get createWalletCreateNewButton => 'Create a new wallet';

  @override
  String get createWalletCreateNewDesc => 'Spice Wallet generates a 15-word BIP39 seed';

  @override
  String get generateSeedTitle => 'Write these down, in order';

  @override
  String get generateSeedTitleCovered => 'Seed Phrase';

  @override
  String get generateSeedSubtitleCovered =>
      'These fifteen words, in this order, are your wallet. Write them down and keep them in a physical safe. If you lose these words or if you share them with anyone else, you will lose your money permanently. Careful planning now avoids a potential disaster later.';

  @override
  String get generateSeedSubtitleRevealed => 'Securely save these. Do not share them.';

  @override
  String get generateSeedScreenshotNote =>
      'Screenshots are blocked on this screen. Make sure nobody is looking over your shoulder.';

  @override
  String get generateSeedReveal => 'Tap to reveal';

  @override
  String get generateSeedBirthdayLabel => 'Wallet birthday';

  @override
  String get generateSeedBirthdayReason => 'Where a future restore starts scanning';

  @override
  String get generateSeedConfirm =>
      'I have written down all 15 words and stored them somewhere only I can reach.';

  @override
  String get generateSeedContinueButton => 'Continue';

  @override
  String get lwsDetailsDescription =>
      'If your Monero light wallet server (LWS) requires registration, you can use these details to add this wallet to that server. Not all servers require registration.';

  @override
  String get restoreWalletTitle => 'Restore wallet';

  @override
  String get restoreWalletSubtitle => 'Any BIP39 phrase, from Spice Wallet or another wallet.';

  @override
  String get restoreWalletSeedLength => 'Seed length';

  @override
  String get restoreWalletPaste => 'Paste';

  @override
  String get restoreWalletScanFrom => 'Scan from';

  @override
  String get restoreWalletScanFromReason => 'Skip irrelevant history to save time';

  @override
  String get restoreWalletNotSet => 'Not set';

  @override
  String get restoreScanTitle => 'When did this wallet first receive funds?';

  @override
  String get restoreScanDescription =>
      'For some assets, Spice Wallet can skip irrelevant history to save you time. Either pick the first month that you used the wallet or select I\'m not sure to check everything. It\'s okay to pick a month that is too early, but it\'s bad to pick a month that is too late.';

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
  String get restoreWalletRestoreButton => 'Restore';

  @override
  String get navigationBarHome => 'Home';

  @override
  String get navigationBarSettings => 'Settings';

  @override
  String get navigationBarHistory => 'History';

  @override
  String get historyTitle => 'History';

  @override
  String get historyFilterBlockchain => 'Blockchain';

  @override
  String get historyFilterAsset => 'Asset';

  @override
  String get historyFilterType => 'Type';

  @override
  String get historyTypeBridge => 'Bridge';

  @override
  String get historyTypeSwap => 'Swap';

  @override
  String get historyTypeAdd => 'Add';

  @override
  String get historyTypeRemove => 'Remove';

  @override
  String get historyFilterReset => 'Reset';

  @override
  String get unlockButton => 'Unlock';

  @override
  String get unlockReason => 'Unlock wallet';

  @override
  String get unlockUnableToAuthError => 'Unable to authenticate.';

  @override
  String get unlockLockedTitle => 'Spice Wallet is locked';

  @override
  String get unlockWithFaceId => 'Unlock with Face ID';

  @override
  String get unlockWithTouchId => 'Unlock with Touch ID';

  @override
  String get unlockPasswordLabel => 'Password';

  @override
  String get unlockPasswordHint => 'Enter your password';

  @override
  String get unlockIncorrectPasswordError => 'Incorrect password. Please try again.';

  @override
  String get homeSyncing => 'Syncing';

  @override
  String get homeSynced => 'Synced';

  @override
  String homeBlocksRemaining(String count) {
    return '$count blocks left';
  }

  @override
  String get homeNoConnection => 'No connection';

  @override
  String get homeCoinNotConfigured => 'Not configured';

  @override
  String homeAssetsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count assets',
      one: '1 asset',
    );
    return '$_temp0';
  }

  @override
  String get coinHomeAssetsTitle => 'Assets';

  @override
  String get coinHomeActivityTitle => 'Activity';

  @override
  String get coinHomeSwap => 'Swap';

  @override
  String get coinHomeSwapComingSoon => 'Coming soon!';

  @override
  String get coinHomeReceived => 'Received';

  @override
  String get coinHomeSent => 'Sent';

  @override
  String get coinHomeAddExplorerTitle => 'Add an explorer to see history';

  @override
  String get coinHomeAddExplorerButton => 'Add explorer';

  @override
  String get homeFiatSource => 'Kraken over Tor';

  @override
  String get homeReceive => 'Receive';

  @override
  String get homeSend => 'Send';

  @override
  String get homeNoTransactions => 'No transactions';

  @override
  String get homeFiatApiError => 'Error connecting to price server';

  @override
  String get homeTotalBalanceLabel => 'Total Balance';

  @override
  String get receiveTitle => 'Receive';

  @override
  String get receivePrimaryAddressWarn =>
      'Warning: Unless you know what you\'re doing, please use subaddresses for better privacy.';

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
  String get sendContactsButton => 'Contacts';

  @override
  String get sendInsufficientBalanceError => 'Insufficient balance.';

  @override
  String get sendInsufficientBalanceToCoverFeeError =>
      'Insufficient balance to cover the network fee.';

  @override
  String get sendInsufficientGasError => 'Insufficient ETH to cover the network fee.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionBehaviour => 'Behaviour';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsSectionWallet => 'Wallet';

  @override
  String get settingsCoinConnectionSection => 'Connection';

  @override
  String get settingsCoinKeysSection => 'Keys';

  @override
  String get settingsCoinConnectionSetup => 'Connection Setup';

  @override
  String get settingsCoinExplorer => 'Explorer';

  @override
  String get settingsCoinNotConfigured => 'Not configured';

  @override
  String get settingsNotifyNewTxsLabel => 'Transaction Notifications';

  @override
  String get settingsNotifyNewTxsDescription =>
      'Show a notification when you receive a transaction. When connected to a Monero node, Background Sync must also be enabled.';

  @override
  String get settingsNotifyNewTxsDescriptionIos =>
      'Show a notification when you receive a transaction.';

  @override
  String get settingsBackgroundSyncLabel => 'Background Sync';

  @override
  String get settingsBackgroundSyncDescription =>
      'Periodically sync your wallets in the background so they\'re up to date when you open the app.';

  @override
  String get settingsForegroundSyncLabel => 'Continuous Sync';

  @override
  String get settingsForegroundSyncDescription =>
      'Keep your wallets syncing continuously while the app runs in the background, with a persistent notification. Uses more battery.';

  @override
  String get settingsAppLockLabel => 'App Lock';

  @override
  String get settingsAppLockUnlockReason => 'Unlock wallet';

  @override
  String get settingsAppLockUnableToAuthError =>
      'Unable to authenticate. Make sure you have device unlock set up.';

  @override
  String get settingsVerboseLoggingLabel => 'Diagnostic Logs';

  @override
  String get settingsTestnetCoinsLabel => 'Testnet Coins';

  @override
  String get settingsTestnetCoinsDescription =>
      'Show testnet coins (e.g. Bitcoin Testnet) in your coin list.';

  @override
  String get settingsVerboseLoggingDescription =>
      'Log wallet operations to a text file in the app\'s data folder for debugging purposes.';

  @override
  String get settingsVerboseLoggingDescriptionIos =>
      'Log wallet operations and allow the logs to be exported to a text file.';

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
  String get settingsThemeLightDesc => 'Warm paper, the default';

  @override
  String get settingsThemeDarkDesc => 'Dark ground, easier at night';

  @override
  String get settingsThemeSystemDesc => 'Follows your phone';

  @override
  String get settingsThemeSheetSubtitle => 'Pick a theme to match your style.';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get settingsLanguageSheetSubtitle => 'Pick your language and localization.';

  @override
  String get settingsSeedPhraseLabel => 'Seed Phrase';

  @override
  String get revealSeedSubtitleCovered =>
      'The same fifteen words this wallet was created with, in the same order.';

  @override
  String get revealSeedSubtitleRevealed =>
      'Securely save these. Do not share them. If you lose these words or if you share them with anyone else, you will lose your money permanently.';

  @override
  String get revealSeedBackButton => 'Back to settings';

  @override
  String get revealSeedHideButton => 'Hide and go back';

  @override
  String get revealSeedAuthReason => 'Confirm it\'s you to view your seed phrase';

  @override
  String get done => 'Done';

  @override
  String get settingsLwsViewKeysButton => 'View';

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
  String get txDetailsCopyHint => 'tap any value to copy';

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
  String get txDetailsChangeRecipientLabel => 'Change Recipient';

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
      'Screenshots are blocked on this screen. Make sure nobody is looking over your shoulder.';

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
  String get addressBookNoContacts => 'No contacts yet';

  @override
  String get addressBookNoContactsDescription => 'Add your first contact by tapping the + button';

  @override
  String get addressBookNoSearchResults => 'No contacts found';

  @override
  String get addressBookEdit => 'Edit';

  @override
  String get addressBookContactName => 'Contact Name';

  @override
  String get addressBookNameHint => 'Name';

  @override
  String get addressBookAddDescription => 'A name and at least one address to pay them.';

  @override
  String get addressBookEditDescription => 'A name and at least one address to pay them.';

  @override
  String get addressBookAddressesLabel => 'Addresses';

  @override
  String get addressBookAddressesNoneYet => 'none yet';

  @override
  String get addressBookUpdate => 'Update';

  @override
  String get addressBookSave => 'Save';

  @override
  String get addressBookAtLeastOneAddressError => 'Enter at least one address';

  @override
  String addressBookNoContactsForCoin(String coinSymbol) {
    return 'No contacts with a $coinSymbol address';
  }

  @override
  String invalidAddressForCoin(String coin) {
    return 'Invalid $coin address';
  }

  @override
  String get sendPriorityLow => 'Low';

  @override
  String get sendPriorityNormal => 'Normal';

  @override
  String get sendPriorityHigh => 'High';

  @override
  String get sendFromLabel => 'From';

  @override
  String get sendToLabel => 'To';

  @override
  String get sendPriorityHeading => 'Priority';

  @override
  String get sendAvailableSuffix => 'available';

  @override
  String get sendNetworkFee => 'Network fee';

  @override
  String get sendMaxButton => 'MAX';

  @override
  String get sendPasteButton => 'Paste';

  @override
  String get sendScanButton => 'Scan';

  @override
  String sendAddressHint(String coin) {
    return '$coin address';
  }

  @override
  String get sendPickContactTitle => 'Send to a contact';

  @override
  String sendPickContactSubtitle(String coin) {
    return 'Pick a contact with a $coin address.';
  }

  @override
  String sendContactNoAddress(String coin) {
    return 'No $coin address';
  }

  @override
  String get sendFailedToGetFeesError => 'Failed to get fees.';

  @override
  String get torSettingsTitle => 'Tor Settings';

  @override
  String get torSettingsSheetSubtitle =>
      'Tor can hide your IP address from servers you connect to. This does not reduce the information that is stored on public blockchains. Changing this reconnects every chain.';

  @override
  String get torSettingsModeBuiltIn => 'Built-in Tor';

  @override
  String get torSettingsModeExternal => 'External Tor';

  @override
  String get torSettingsModeDisabled => 'No Tor';

  @override
  String get torSettingsSocksPortLabel => 'SOCKS Port';

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
  String get connectionRemoteIpNotAllowed =>
      'Connections to remote IP addresses aren\'t allowed. Use a domain name or a local IP address.';

  @override
  String get connectionProtocolHttps => 'Removing protocol. Using HTTPS for domains.';

  @override
  String get connectionProtocolHttp => 'Removing protocol. Using HTTP for local addresses.';

  @override
  String get settingsTorSettingsLabel => 'Tor Settings';

  @override
  String get lwsSetupTorDisabledError => 'Tor is disabled. Please go back and enable it.';

  @override
  String get lwsSetupInvalidQrCode => 'Invalid connection address.';

  @override
  String get save => 'Save';

  @override
  String get explorerSetupTitle => 'Block Explorer Setup';

  @override
  String get explorerSetupDescription =>
      'Optionally set a Blockscout explorer instance to load full transaction history. Only select a server you trust. Even if you use Tor, this server can learn information about you.';

  @override
  String get explorerAddressLabel => 'Explorer Address';

  @override
  String get explorerRemovedMessage => 'Explorer removed.';
}
