// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
  String get lwsSetupDescription =>
      'Connect to a Monero light-wallet server (LWS) or your own full node. Only select a server you trust. Even if you use Tor, this server can learn information about you. With an LWS, your private view key and primary address will be shared with this server.';

  @override
  String get lwsSetupProxyPortLabel => 'HTTP Proxy Port (Optional)';

  @override
  String get lwsSetupProxyPortHint => '4444 for I2P';

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
  String get settingsConnectionInLocalNetwork => 'in local network';

  @override
  String get fiatApiSetupDescription =>
      'Skylight Wallet can automatically fetch the latest Monero price. Your balances are not sent to the server. How do you want to fetch this price data?';

  @override
  String get createWalletDescription =>
      'Would you like to create a new wallet or restore an existing wallet?';

  @override
  String get createWalletRestoreExistingDesc => 'Enter an existing Monero recovery phrase';

  @override
  String get createWalletCreateNewDesc =>
      'Skylight Wallet generates a new Polyseed recovery phrase';

  @override
  String get generateSeedSubtitleCovered =>
      'These words, in this order, are your wallet. Write them down and keep them in a physical safe. If you lose these words or if you share them with anyone else, you will lose your money permanently. Careful planning now avoids a potential disaster later.';

  @override
  String get onboardingConnectionNoteServer =>
      'Use a light-wallet server (LWS) or your own Monero node.';

  @override
  String get onboardingConnectionNoteChangeable => 'You can change this later in Settings.';

  @override
  String get lwsDetailsTitle => 'Wallet Details';

  @override
  String get lwsDetailsPrimaryAddressLabel => 'Primary Address';

  @override
  String get lwsDetailsSecretViewKeyLabel => 'Secret View Key';

  @override
  String get lwsDetailsRestoreHeightLabel => 'Restore Height';

  @override
  String get restoreWalletDescription =>
      'Input your Monero recovery phrase below. We will check common formats.';

  @override
  String get restoreScanDescription =>
      'Skylight Wallet can skip irrelevant history to save you time. Either pick the first month that you used the wallet or select I\'m not sure to check everything. It\'s okay to pick a month that is too early, but it\'s bad to pick a month that is too late.';

  @override
  String get restoreWalletInvalidMnemonic => 'Invalid recovery phrase.';

  @override
  String get restoreWalletSeedTypePolyseed => 'Polyseed';

  @override
  String get restoreWalletSeedTypeBip39 => 'BIP39';

  @override
  String get restoreWalletSeedTypeLegacy => 'Legacy';

  @override
  String get navigationBarWallet => 'Wallet';

  @override
  String get historyFilterAddress => 'Address';

  @override
  String get historyFilterAddressAny => 'Any Address';

  @override
  String get historyFilterAddressHint => 'Transactions received at this address, or sent to it.';

  @override
  String get historyFilterAddressInvalid => 'Not a Monero address';

  @override
  String get unlockTitle => 'Unlock Wallet';

  @override
  String get homeDisconnected => 'Disconnected';

  @override
  String get receiveQrHint => 'Scan this code to send Monero to this wallet.';

  @override
  String get sendInvalidAddressError => 'Invalid address.';

  @override
  String get syncFrequencySheetSubtitle => 'How often Monero syncs while the app is closed.';

  @override
  String get syncFrequencyContinuousDesc =>
      'Continuously sync Monero in the background so it\'s always up to date when you open the app. Uses more battery and requires a persistent notification.';

  @override
  String get syncFrequencyPeriodicDesc =>
      'Periodically sync Monero in the background so it\'s usually up to date when you open the app. With a Monero node, it only syncs while charging and on WiFi.';

  @override
  String get syncFrequencyPeriodicDescIos =>
      'Periodically sync Monero in the background so it\'s usually up to date when you open the app. With a Monero node, it only syncs while charging.';

  @override
  String get settingsThemeLightDesc => 'Light and clean';

  @override
  String get settingsLwsViewKeysLabel => 'LWS View Keys';

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
  String get secretKeysTitle => 'Secret Restore Keys';

  @override
  String get secretKeysDescription =>
      'These recovery phrases and keys restore full control of your wallet. Anyone who sees them can spend your funds.';

  @override
  String get secretKeysMnemonic => 'Recovery Phrase';

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
  String get addressBookAddDescription => 'A name and a Monero address to pay them on.';

  @override
  String get addressBookEditDescription => 'Update this contact\'s name or address.';

  @override
  String get sendIrreversibleNote =>
      'Transactions are irreversible, so make sure the address and amount are correct.';

  @override
  String get torChoiceSubtitle =>
      'Tor can hide your IP address from servers you connect to. This does not reduce the information that is stored on public blockchains. In general, how do you want Skylight Wallet to handle Tor connections?';

  @override
  String get torSettingsSheetSubtitle =>
      'Tor can hide your IP address from servers you connect to. This does not reduce the information that is stored on public blockchains. Changing this reconnects your wallet.';
}
