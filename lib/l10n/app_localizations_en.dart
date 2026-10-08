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
  String get back => 'Back';

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
  String get lwsSetupTitle => 'Connection Setup';

  @override
  String get lwsSetupDescription =>
      'Connect to a Monero light-wallet server (LWS) or your own full node. Only select a server you trust. Even if you use Tor, this server can learn information about you. With an LWS, your private view key and primary address will be shared with this server.';

  @override
  String get lwsSetupProxyPortLabel => 'HTTP Proxy Port (Optional)';

  @override
  String get lwsSetupProxyPortHint => '4444 for I2P';

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
  String get fiatApiSetupTitle => 'Price Display Setup';

  @override
  String get fiatApiSetupDescription =>
      'Skylight Wallet can automatically fetch the latest Monero price. Your balances are not sent to the server. How do you want to fetch this price data?';

  @override
  String get fiatApiSettingsModeLabel => 'Mode';

  @override
  String get fiatApiSettingsModeTorOnly => 'Tor-Only';

  @override
  String get fiatApiSettingsModeClearnet => 'Clearnet-Only (Not Private)';

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
  String get createWalletTitle => 'Wallet Setup';

  @override
  String get createWalletDescription =>
      'Would you like to create a new wallet or restore an existing wallet?';

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
  String get generateSeedTitleCovered => 'Seed Phrase';

  @override
  String get generateSeedSubtitleCovered =>
      'These words, in this order, are your wallet. Write them down and keep them in a physical safe. If you lose these words or if you share them with anyone else, you will lose your money permanently. Careful planning now avoids a potential disaster later.';

  @override
  String get generateSeedSubtitleRevealed => 'Securely save these. Do not share them.';

  @override
  String get generateSeedScreenshotNote =>
      'Screenshots are blocked on this screen. Make sure nobody is looking over your shoulder.';

  @override
  String get generateSeedReveal => 'Tap to reveal';

  @override
  String get generateSeedConfirm =>
      'I have written down all the words and stored them somewhere only I can reach.';

  @override
  String get generateSeedBirthdayLabel => 'Wallet birthday';

  @override
  String get generateSeedBirthdayReason => 'Where a future restore starts scanning';

  @override
  String get onboardingTorNotePrivacy =>
      'Tor hides your address from the node you query — slower, and worth it.';

  @override
  String get onboardingTorNoteChangeable => 'Changeable later under Settings → Connections.';

  @override
  String get onboardingPriceNoteRatesOnly =>
      'The price service is asked for rates only — never for addresses or amounts.';

  @override
  String get onboardingPriceNoteTor => 'Routed over Tor by default, separately from chain traffic.';

  @override
  String get onboardingConnectionNoteServer =>
      'Point Skylight at a light-wallet server (LWS), or connect to your own Monero node.';

  @override
  String get onboardingConnectionNoteChangeable => 'Changeable later under Settings → Connection.';

  @override
  String get onboardingWalletNoteGenerated =>
      'A new wallet’s seed is generated here, offline, and shown to you once.';

  @override
  String get onboardingWalletNoteRestore =>
      'Restoring asks roughly when the seed first held funds, to skip years of scanning.';

  @override
  String get onboardingWalletCreateBullet1 => 'A Monero seed phrase, shown once';

  @override
  String get onboardingWalletCreateBullet2 => 'Starts empty, syncs from today';

  @override
  String get onboardingWalletCreateBullet3 => 'Takes about two minutes';

  @override
  String get onboardingWalletRestoreBullet1 => 'A Polyseed, BIP39 or legacy Monero seed';

  @override
  String get onboardingWalletRestoreBullet2 => 'Optional scan-from date';

  @override
  String get onboardingWalletRestoreBullet3 => 'Recovers your existing balance and history';

  @override
  String get onboardingSeedNotePassword =>
      'Skylight Wallet asks for your password before ever showing them again.';

  @override
  String get onboardingPasswordNoteLaunch =>
      'Asked for at every launch, and before the seed is ever shown.';

  @override
  String get onboardingPasswordNoteNotCloud =>
      'Not a cloud account. Losing it means restoring from your seed phrase.';

  @override
  String get onboardingPasswordStrong => 'Strong';

  @override
  String get onboardingPasswordMatch => 'Both entries match';

  @override
  String get lwsDetailsTitle => 'Wallet Details';

  @override
  String get lwsDetailsDescription =>
      'If your Monero light wallet server (LWS) requires registration, you can use these details to add this wallet to that server. Not all servers require registration.';

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
  String get restoreWalletScanFrom => 'Scan from';

  @override
  String get restoreWalletScanFromReason => 'Skip irrelevant history to save time';

  @override
  String get restoreWalletNotSet => 'Not set';

  @override
  String get restoreScanTitle => 'When did this wallet first receive funds?';

  @override
  String get restoreScanDescription =>
      'Skylight Wallet can skip irrelevant history to save you time. Either pick the first month that you used the wallet or select I\'m not sure to check everything. It\'s okay to pick a month that is too early, but it\'s bad to pick a month that is too late.';

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
  String get unlockWithFaceId => 'Unlock with Face ID';

  @override
  String get unlockWithTouchId => 'Unlock with Touch ID';

  @override
  String get unlockTitle => 'Unlock Wallet';

  @override
  String get unlockPasswordHint => 'Enter your password';

  @override
  String get unlockIncorrectPasswordError => 'Incorrect password. Please try again.';

  @override
  String get homeSyncing => 'Syncing';

  @override
  String get homeSynced => 'Synced';

  @override
  String get homeTorConnected => 'Tor · connected';

  @override
  String get homeTorConnecting => 'Tor · connecting';

  @override
  String get homeTorOff => 'Tor · off';

  @override
  String get homeReceive => 'Receive';

  @override
  String get homeSend => 'Send';

  @override
  String get homeNoTransactions => 'No Transactions';

  @override
  String get homeFiatApiError => 'Error connecting to price server';

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
  String get receiveQrHint => 'Scan this code to send Monero to this wallet.';

  @override
  String get receiveEnlargeQr => 'Tap to enlarge and brighten';

  @override
  String get receiveShrinkQr => 'Tap to shrink';

  @override
  String get receiveShareError => 'Could not open the share sheet';

  @override
  String receiveAddressHeading(String coin) {
    return 'Your $coin address';
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
  String get settingsNotifyNewTxsLabel => 'Transaction Notifications';

  @override
  String get settingsNotifyNewTxsDescription =>
      'Show a notification when you receive a transaction. When connected to a Monero node, Background Sync must also be enabled.';

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
  String get settingsVerboseLoggingLabel => 'Diagnostic Logs';

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
  String get settingsExportLogsFailed => 'Could not export the log file';

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
  String get settingsThemeSheetSubtitle => 'Pick a theme to match your style.';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get settingsLanguageSheetSubtitle => 'Pick your language and localization.';

  @override
  String get settingsFiatApiSettingsLabel => 'Price Display Settings';

  @override
  String get settingsLwsViewKeysLabel => 'LWS View Keys';

  @override
  String get settingsLwsViewKeysButton => 'View';

  @override
  String get revealSeedAuthReason => 'Confirm it\'s you to view your seed phrase';

  @override
  String get settingsSecretKeysLabel => 'Secret Restore Keys';

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
  String get txDetailsReceivedAtLabel => 'Received At';

  @override
  String get txDetailsChangeRecipientLabel => 'Change Recipient';

  @override
  String get unconfirmed => 'Unconfirmed';

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
      'Screenshots are blocked on this screen. Make sure nobody is looking over your shoulder.';

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
  String get addressBookEdit => 'Edit';

  @override
  String get addressBookContactName => 'Contact Name';

  @override
  String get addressBookNameHint => 'Name';

  @override
  String get addressBookAddDescription => 'A name and a Monero address to pay them on.';

  @override
  String get addressBookEditDescription => 'Update this contact\'s name or address.';

  @override
  String get addressBookUpdate => 'Update';

  @override
  String get addressBookSave => 'Save';

  @override
  String get sendPriorityLow => 'Low';

  @override
  String get sendPriorityNormal => 'Normal';

  @override
  String get sendPriorityHigh => 'High';

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
  String get sendIrreversibleNote =>
      'Monero transactions are irreversible. Double-check the address and amount before sending.';

  @override
  String get sendSwitchUnit => 'Switch amount unit';

  @override
  String get sendFailedToGetFeesError => 'Failed to get fees.';

  @override
  String get torSettingsTitle => 'Tor Settings';

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
  String get torChoiceTitle => 'Tor Connection Setup';

  @override
  String get torChoiceSubtitle =>
      'Tor can hide your IP address from servers you connect to. This does not reduce the information that is stored on public blockchains. In general, how do you want Skylight Wallet to handle Tor connections?';

  @override
  String get torSettingsSocksPortLabel => 'SOCKS Port';

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
  String get lwsSetupTorDisabledError => 'Tor is disabled. Please go back and enable it.';

  @override
  String get lwsSetupInvalidQrCode => 'Invalid connection address.';

  @override
  String get advancedSecurityLabel => 'Advanced security';

  @override
  String get advancedSecurityTitle => 'Advanced security';

  @override
  String get advancedSecurityOff => 'Off';

  @override
  String advancedSecurityKeyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count keys',
      one: '1 key',
    );
    return '$_temp0';
  }

  @override
  String get securityKeysSection => 'Security keys';

  @override
  String get securityKeysIntroTitle => 'Protect this wallet with a security key';

  @override
  String get securityKeysIntroBody =>
      'Require a YubiKey and its PIN, or the fingerprint on a YubiKey Bio, to open this wallet. Without one of your keys, the wallet file on this phone cannot be decrypted, even by someone who can unlock the phone.';

  @override
  String get securityKeysRequirements =>
      'Works with YubiKey 5 series keys over NFC or USB-C, and with YubiKey Bio over USB-C on Android. On iPhone, USB-C needs YubiKey firmware 5.8 or later. Each key needs a FIDO2 PIN.';

  @override
  String get securityKeysSuggestTwo =>
      'Set up two or more keys and keep one somewhere safe. Your recovery phrase still restores the wallet if you lose them all.';

  @override
  String get securityKeysSetUpButton => 'Set up security keys';

  @override
  String get securityKeysUnavailable =>
      'Security keys need a wallet created or restored with this version of Skylight.';

  @override
  String get securityKeysYourKeys => 'Your keys';

  @override
  String securityKeysAdded(String date) {
    return 'Added $date';
  }

  @override
  String get securityKeysOneKeyWarning =>
      'You have one key. If you lose it, you will need your recovery phrase to open this wallet. Add a second key as a backup.';

  @override
  String get securityKeysAddButton => 'Add a security key';

  @override
  String get securityKeysManageSection => 'Manage';

  @override
  String get securityKeysRemoveTitle => 'Remove a key';

  @override
  String get securityKeysRemoveSubtitle => 'Set up again with only the keys you keep';

  @override
  String get securityKeysRemoveLink => 'Set up';

  @override
  String get securityKeysRemoveExplain =>
      'To remove a key, set up your keys again with only the keys you want to keep. Any key you leave out stops working for this wallet. Have every key you keep with you.';

  @override
  String get securityKeysRemoveConfirm => 'Set up again';

  @override
  String get securityKeysTurnOff => 'Turn off security keys';

  @override
  String get securityKeysTurnOffBody =>
      'The wallet password goes back into this phone\'s secure storage, and the wallet opens without a key.';

  @override
  String get securityKeysTurnOffConfirm => 'Turn off';

  @override
  String get securityKeysTurnedOff => 'Security keys are off';

  @override
  String get securityKeysTurnedOn => 'Security keys are on';

  @override
  String get securityKeysLockSection => 'Lock';

  @override
  String get securityKeysFullLockLabel => 'Fully lock after';

  @override
  String get securityKeysFullLockDescription =>
      'After this long in the background, Skylight closes the wallet and forgets its password. Opening it again needs a security key.';

  @override
  String securityKeysMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String securityKeysHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String get securityKeysBackgroundNote =>
      'Background sync keeps working with your view key, which can see incoming payments but cannot spend.';

  @override
  String get securityKeysSetupTitle => 'Set up security keys';

  @override
  String get securityKeysSetupAgainTitle => 'Set up keys again';

  @override
  String get securityKeysSetupAgainNote =>
      'Add only the keys you want to keep. Any key you leave out will no longer open this wallet.';

  @override
  String get securityKeysAddFirst => 'Add your first key';

  @override
  String get securityKeysAddAnother => 'Add another key';

  @override
  String get securityKeysFinish => 'Finish';

  @override
  String get securityKeysOneKeyTitle => 'Finish with one key?';

  @override
  String get securityKeysOneKeyBody =>
      'We suggest two or more. If you lose your only key, you will need your recovery phrase to open this wallet.';

  @override
  String get securityKeysFinishAnyway => 'Finish anyway';

  @override
  String get securityKeysNameLabel => 'Key name';

  @override
  String securityKeysNameDefault(int number) {
    return 'YubiKey $number';
  }

  @override
  String get securityKeysPinLabel => 'Key PIN';

  @override
  String get securityKeysContinue => 'Continue';

  @override
  String get securityKeysNewPinTitle => 'Create a PIN for this key';

  @override
  String get securityKeysNewPinLabel => 'New PIN';

  @override
  String get securityKeysConfirmPinLabel => 'Confirm PIN';

  @override
  String get securityKeysSetPinButton => 'Set PIN';

  @override
  String get securityKeysPinMismatch => 'The PINs do not match.';

  @override
  String securityKeysErrorPinInvalid(int count) {
    return 'Incorrect PIN. $count attempts left before the key locks.';
  }

  @override
  String get securityKeysErrorPinInvalidUnknown => 'Incorrect PIN.';

  @override
  String get securityKeysErrorPinBlocked =>
      'This key\'s PIN is blocked. The key must be reset, which removes it from every wallet it protects.';

  @override
  String get securityKeysErrorPinAuthBlocked =>
      'Too many wrong PINs in a row. Remove the key and connect it again.';

  @override
  String get securityKeysErrorPinPolicy =>
      'The key did not accept that PIN. Some keys need at least 6 characters.';

  @override
  String get securityKeysErrorNotEnrolled => 'This key is not set up for this wallet.';

  @override
  String get securityKeysErrorAlreadyAdded => 'This key is already set up for this wallet.';

  @override
  String securityKeysErrorUnsupported(String reason) {
    return 'This key cannot be used here: $reason';
  }

  @override
  String get securityKeysErrorTimeout => 'No key was found. Try again.';

  @override
  String get securityKeysErrorTransport => 'The connection to the key was lost. Try again.';

  @override
  String securityKeysErrorGeneric(String reason) {
    return 'Something went wrong: $reason';
  }

  @override
  String get securityKeyUnlockTitle => 'Unlock with your security key';

  @override
  String get securityKeyUnlockButton => 'Unlock';

  @override
  String get securityKeyLostKeys => 'Lost your keys?';

  @override
  String get securityKeyLostKeysBody =>
      'Your recovery phrase can open this wallet. Then set up new keys in Settings.';

  @override
  String get securityKeyUseRecoveryPhrase => 'Use recovery phrase';

  @override
  String get securityKeyRecoveryPhraseHint => 'Enter your recovery phrase';

  @override
  String get securityKeyRecoveryWrongPhrase => 'That recovery phrase is not this wallet\'s.';

  @override
  String get securityKeyRecoveryNotPossible =>
      'This wallet came from a 25-word seed, so its phrase cannot open it here. Delete the wallet and restore it from the phrase.';

  @override
  String get securityKeyRecoveredToast =>
      'Unlocked with your recovery phrase. Set up your keys again in Settings.';

  @override
  String get securityKeyConnectTitle => 'Connect your security key';

  @override
  String get securityKeyConnectBodyAndroid =>
      'Plug your YubiKey into the USB-C port and touch it when it blinks, or hold it flat against the back of your phone.';

  @override
  String get securityKeyConnectBodyIos =>
      'Hold your YubiKey near the top of your iPhone, or plug it in and touch it when it blinks.';

  @override
  String get securityKeyConnectButton => 'Connect key';

  @override
  String get securityKeyTryAgain => 'Try again';

  @override
  String get securityKeyWaiting => 'Waiting for your key…';

  @override
  String get securityKeyTalkingToKey => 'Talking to your key…';

  @override
  String get securityKeyKeyBlinking => 'Your key is blinking';

  @override
  String get securityKeyTouchToSelect => 'Touch your key';

  @override
  String get securityKeyTouchBody => 'Touch the gold contact on your key while it blinks.';

  @override
  String get securityKeyPinTitle => 'Enter your key\'s PIN';

  @override
  String get securityKeyPinBody =>
      'The PIN you set for this YubiKey. It is not your phone\'s passcode.';

  @override
  String securityKeyPinAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts left before the key locks.',
      one: '1 attempt left before the key locks.',
    );
    return '$_temp0';
  }

  @override
  String get securityKeyUseAnotherKey => 'Use a different key';

  @override
  String get securityKeyUseFingerprint => 'Use fingerprint instead';

  @override
  String get securityKeyUsePin => 'Use PIN instead';

  @override
  String securityKeysNewPinBodyCount(int count) {
    return 'This key has no PIN yet. Choose one with at least $count characters. Skylight requires it, so a key found by someone else cannot open your wallet.';
  }

  @override
  String securityKeysPinTooShortCount(int count) {
    return 'Use at least $count characters.';
  }

  @override
  String get securityKeyCheckingPin => 'Checking your PIN…';

  @override
  String get securityKeyWorking => 'One moment…';

  @override
  String get securityKeyKeepHolding => 'Keep your key against the phone.';

  @override
  String get securityKeyHoldAgain => 'Hold your key to your phone again';

  @override
  String get securityKeyConnectAgain => 'Connect your key again';

  @override
  String get securityKeyTouchToConfirm => 'Touch your key to confirm';

  @override
  String get securityKeyTouchOnceMore => 'Touch your key once more';

  @override
  String get securityKeyTouchToUnlock => 'Touch your key to unlock';

  @override
  String get securityKeyFingerprintToConfirm => 'Touch the fingerprint sensor';

  @override
  String get securityKeyFingerprintOnceMore => 'Touch the sensor once more';

  @override
  String get securityKeyFingerprintToUnlock => 'Touch the sensor to unlock';

  @override
  String get securityKeyFingerprintBody => 'Use a finger you enrolled on this YubiKey Bio.';

  @override
  String securityKeyTouchCount(int current, int total) {
    return 'Touch $current of $total';
  }

  @override
  String get securityKeyAddedTitle => 'Key added';

  @override
  String get securityKeyNameBody => 'Give it a name so you can tell your keys apart.';

  @override
  String get securityKeySaveName => 'Save';

  @override
  String get securityKeysErrorKeyUnsupported =>
      'This key cannot protect a wallet. Use a YubiKey 5 series key or a YubiKey Bio.';

  @override
  String get securityKeysErrorPinChangeRequired =>
      'This key wants a new PIN first. Change it in the Yubico Authenticator app, then try again.';

  @override
  String securityKeysErrorUvInvalid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fingerprint not recognized. $count tries left.',
      one: 'Fingerprint not recognized. 1 try left.',
    );
    return '$_temp0';
  }

  @override
  String get securityKeysErrorUvInvalidUnknown => 'Fingerprint not recognized.';

  @override
  String get securityKeysErrorUvBlocked =>
      'The fingerprint reader on this key is locked. Enter the key\'s PIN instead.';

  @override
  String get securityKeysErrorUvNotConfigured =>
      'This key has no fingerprint set up. Enter its PIN instead.';

  @override
  String securityKeyPinTitleNamed(String name) {
    return 'Enter the PIN for $name';
  }

  @override
  String securityKeysSerial(String serial) {
    return 'Serial $serial';
  }

  @override
  String get securityKeysErrorDifferentKey =>
      'That is a different key from the one you touched. Start again with the key you want to use.';
}
