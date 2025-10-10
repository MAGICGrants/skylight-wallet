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
  String get fieldEmptyError => 'This field cannot be empty.';

  @override
  String get welcomeTitle => 'Welcome!';

  @override
  String get welcomeDescription =>
      'Light Monero Wallet is one of the simplest Monero wallets. We will help you set up a wallet and connect to a server.';

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
  String get connectionSetupTitle => 'Connection Setup';

  @override
  String get connectionSetupDescription =>
      'Let\'s setup a connection with LWS.';

  @override
  String get connectionSetupAddressHint =>
      'e.g. 192.168.1.1:18090 or example.com:18090';

  @override
  String get connectionSetupProxyPortLabel => 'HTTP Proxy Port (optional)';

  @override
  String get connectionSetupProxyPortHint => 'e.g. 4444 for I2P';

  @override
  String get connectionSetupUseTorLabel => 'Use Tor';

  @override
  String get connectionSetupUseSslLabel => 'Use SSL';

  @override
  String get connectionSetupTestConnectionButton => 'Test Connection';

  @override
  String get connectionSetupContinueButton => 'Continue';

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
      'This is your polyseed. Write it down and keep it in a safe place.';

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
      'Input your Monero seed below. We will check common formats.';

  @override
  String get restoreWalletSeedLabel => 'Seed';

  @override
  String get restoreWalletRestoreHeightLabel => 'Restore Height';

  @override
  String get restoreWalletRestoreButton => 'Restore';

  @override
  String get restoreWalletInvalidMnemonic => 'Invalid mnemonic.';

  @override
  String get navigationBarWallet => 'Wallet';

  @override
  String get navigationBarSettings => 'Settings';

  @override
  String get navigationBarKeys => 'Keys';

  @override
  String get unlockButton => 'Unlock';

  @override
  String get unlockReason => 'Unlock wallet';

  @override
  String get unlockUnableToAuthError => 'Unable to authenticate.';

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
  String get receivePrimaryAddressWarn =>
      'Warning: For better privacy, consider using subaddresses if supported by your light wallet server.';

  @override
  String get receiveSubaddressWarn =>
      'Warning: Make sure your light wallet server supports subaddresses, otherwise, you will not be able to see incoming transactions.';

  @override
  String get receiveShareButton => 'Share';

  @override
  String get receiveShowSubaddressButton => 'Show Subaddress';

  @override
  String get receiveShowPrimaryAddressButton => 'Show Primary Address';

  @override
  String get sendTitle => 'Send';

  @override
  String get sendSendButton => 'Send';

  @override
  String get sendTransactionSuccessfullySent =>
      'Transaction successfully sent!';

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
  String get settingsNotifyNewTxsLabel => 'Notify New Transactions';

  @override
  String get settingsAppLockLabel => 'App Lock';

  @override
  String get settingsAppLockUnlockReason => 'Unlock wallet';

  @override
  String get settingsAppLockUnableToAuthError => 'Unable to authenticate.';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get settingsDisplayCurrencyLabel => 'Display Currency';

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
      'Only share this information with your LWS server. These keys allow the holder to permanently see all transactions related to your wallets. Sharing these with an untrusted person will significantly harm your privacy.';

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
}
