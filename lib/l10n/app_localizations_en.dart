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
  String get fieldEmptyError => 'This field cannot be empty.';

  @override
  String get welcomeTitle => 'Welcome!';

  @override
  String get welcomeDescription =>
      'Skylight is one of the simplest Monero wallets. We will help you set up a wallet and connect to a server.';

  @override
  String get welcomeGetStarted => 'Get Started';

  @override
  String get restoreWarningTitle => 'Restore Warning';

  @override
  String get restoreWarningDescription =>
      'Are you sure? The server that you connect to will be able to see your past and future Monero transaction history.';

  @override
  String get restoreWarningContinueButton => 'Continue';

  @override
  String get lwsSetupTitle => 'LWS Setup';

  @override
  String get lwsSetupDescription => 'Enter the address of your Monero light-wallet server (LWS).';

  @override
  String get connectionSetupTitle => 'Connection Setup';

  @override
  String connectionSetupDescription(String type) {
    return 'Enter the address of your $type.';
  }

  @override
  String get connectionTypeLws => 'Light Wallet Server';

  @override
  String get connectionTypeNode => 'Monero Node';

  @override
  String get lwsSetupAddressHint => 'e.g. 192.168.1.1:18090 or example.com:18090';

  @override
  String get lwsSetupProxyPortLabel => 'HTTP Proxy Port (optional)';

  @override
  String get lwsSetupProxyPortHint => 'e.g. 4444 for I2P';

  @override
  String get lwsSetupUseTorLabel => 'Use Tor';

  @override
  String get lwsSetupUseSslLabel => 'Use SSL';

  @override
  String get lwsSetupTestConnectionButton => 'Test Connection';

  @override
  String get lwsSetupStartingTor => 'Starting Tor...';

  @override
  String get lwsSetupContinueButton => 'Continue';

  @override
  String get fiatApiSetupTitle => 'Fiat Display Setup';

  @override
  String get fiatApiSetupDescription => 'Optional reference price for your XMR balance.';

  @override
  String get fiatApiSettingsModeLabel => 'Mode';

  @override
  String get fiatApiSettingsModeTorOnly => 'Tor-Only';

  @override
  String get fiatApiSettingsModeClearnet => 'Clearnet-Only (not private)';

  @override
  String get fiatApiSettingsModeDisabled => 'Disabled';

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
  String get createWalletCreateNewButton => 'Create New';

  @override
  String get generateSeedTitle => 'New Wallet';

  @override
  String get generateSeedDescription =>
      'This is your 15-word seed phrase. Write it down and keep it in a safe place. It can restore every coin in this wallet.';

  @override
  String get generateSeedContinueButton => 'I wrote it down';

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
      'Enter your 15-word seed phrase to restore every coin in this wallet.';

  @override
  String get restoreWalletSeedLabel => 'Seed';

  @override
  String get restoreWalletRestoreHeightLabel => 'Restore Height (optional)';

  @override
  String get restoreWalletRestoreDateLabel => 'Restore from date';

  @override
  String get restoreWalletRestoreButton => 'Restore';

  @override
  String get restoreWalletInvalidMnemonic => 'Invalid seed.';

  @override
  String get navigationBarWallet => 'Wallet';

  @override
  String get navigationBarSettings => 'Settings';

  @override
  String get unlockButton => 'Unlock';

  @override
  String get unlockReason => 'Unlock wallet';

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
  String get homeBalanceLocked => 'locked';

  @override
  String get homeTransactionsTitle => 'Transactions';

  @override
  String get homeOutgoingTxSemanticLabel => 'Outgoing Transaction';

  @override
  String get homeIncomingTxSemanticLabel => 'Incoming Transaction';

  @override
  String get homeTransactionConfirmed => 'Confirmed';

  @override
  String get homeNoTransactions => 'No transactions';

  @override
  String get homeFiatApiError => 'Error connecting to fiat API';

  @override
  String get homeTotalBalanceLabel => 'Total Balance';

  @override
  String get homeYourCoinsTitle => 'Your Coins';

  @override
  String get homeCoinNotConfigured => 'Not configured';

  @override
  String get homeCoinSetUp => 'Set up';

  @override
  String get homeConnectionErrorTooltip => 'Couldn\'t connect to the server';

  @override
  String get coinHomeServerConnectionButton => 'Server connection';

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
  String get sendInvalidAddressError => 'Invalid address.';

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
  String get settingsNotifyNewTxsLabel => 'Notify New Transactions';

  @override
  String get settingsAppLockLabel => 'App Lock';

  @override
  String get settingsAppLockUnlockReason => 'Unlock wallet';

  @override
  String get settingsAppLockUnableToAuthError =>
      'Unable to authenticate. Make sure you have device unlock set up.';

  @override
  String get settingsVerboseLoggingLabel => 'Verbose Logging';

  @override
  String get settingsTestnetCoinsLabel => 'Testnet Coins';

  @override
  String get settingsTestnetCoinsDescription =>
      'Show testnet coins (e.g. Bitcoin Testnet) in your coin list.';

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
  String get settingsLanguageLabel => 'Language';

  @override
  String get settingsFiatApiSettingsLabel => 'Fiat API Settings';

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
  String get txDetailsTitle => 'Transaction';

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
  String get lwsKeysTitle => 'LWS Keys';

  @override
  String get lwsKeysPrimaryAddress => 'Primary Address';

  @override
  String get lwsKeysRestoreHeight => 'Restore Height';

  @override
  String get lwsKeysSecretViewKey => 'Secret View Key';

  @override
  String get secretKeysTitle => 'Secret Restore Keys';

  @override
  String get secretKeysMnemonic => 'Seed';

  @override
  String get secretKeysPublicSpendKey => 'Public Spend Key';

  @override
  String get secretKeysSecretSpendKey => 'Secret Spend Key';

  @override
  String get secretKeysPublicViewKey => 'Public View Key';

  @override
  String get scanQrTitle => 'Scan QR Code';

  @override
  String get confirmSendTitle => 'Confirm Send';

  @override
  String get confirmSendDescription =>
      'Transactions are irreversible, so make sure that these details match exactly.';

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
  String get addressBookCopyAddress => 'Copy Address';

  @override
  String get addressBookEdit => 'Edit';

  @override
  String get addressBookContactName => 'Contact Name';

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
  String get sendSelectedContact => 'Selected contact';

  @override
  String get sendClearSelectedContact => 'Clear selected contact';

  @override
  String get sendPriorityLow => 'Low';

  @override
  String get sendPriorityNormal => 'Normal';

  @override
  String get sendPriorityHigh => 'High';

  @override
  String get sendPriorityLabel => 'priority';

  @override
  String get sendTransactionPriority => 'Transaction Priority';

  @override
  String get sendFeeLabel => 'Fee';

  @override
  String get sendBalanceLabel => 'Balance';

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
  String get settingsLwsSettingsLabel => 'LWS Settings';

  @override
  String get settingsTorSettingsLabel => 'Tor Settings';

  @override
  String get lwsSetupUsingInternalTor => 'Using internal Tor';

  @override
  String lwsSetupUsingExternalTor(String address) {
    return 'Using external Tor proxy at $address';
  }

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
      'Optionally set a Blockscout instance to load full transaction history. Leave empty to disable — future sent transactions still appear without it.';

  @override
  String get explorerAddressLabel => 'Explorer Address';

  @override
  String get explorerRemoveButton => 'Remove Explorer';

  @override
  String get explorerRemovedMessage => 'Explorer removed.';

  @override
  String get explorerSetupButton => 'Set Up Explorer';

  @override
  String get explorerSetupHint => 'Set up a block explorer to see your full transaction history.';

  @override
  String get legacyTitle => 'Unsupported Wallet';

  @override
  String get legacyDescription =>
      'Skylight Wallet is dropping support for legacy and polyseed seed phrases in favor of BIP39. Please write down the seed phrase below, delete this wallet and create a new wallet. You can restore the seed below on another Monero wallet and move the funds to your new BIP39 seed wallet.';

  @override
  String get legacyShowSeedButton => 'Show seed';

  @override
  String get legacySeedLabel => 'Seed';

  @override
  String get legacyError => 'Couldn\'t open the wallet. Check your password and try again.';
}
