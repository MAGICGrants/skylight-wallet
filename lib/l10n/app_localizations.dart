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

  /// No description provided for @lwsSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect to a Monero light-wallet server (LWS) or your own full node. Only select a server you trust. Even if you use Tor, this server can learn information about you. With an LWS, your private view key and primary address will be shared with this server.'**
  String get lwsSetupDescription;

  /// No description provided for @lwsSetupProxyPortLabel.
  ///
  /// In en, this message translates to:
  /// **'HTTP Proxy Port (Optional)'**
  String get lwsSetupProxyPortLabel;

  /// No description provided for @lwsSetupProxyPortHint.
  ///
  /// In en, this message translates to:
  /// **'4444 for I2P'**
  String get lwsSetupProxyPortHint;

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
  /// **'in local network'**
  String get settingsConnectionInLocalNetwork;

  /// No description provided for @fiatApiSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'Skylight Wallet can automatically fetch the latest Monero price. Your balances are not sent to the server. How do you want to fetch this price data?'**
  String get fiatApiSetupDescription;

  /// No description provided for @createWalletDescription.
  ///
  /// In en, this message translates to:
  /// **'Would you like to create a new wallet or restore an existing wallet?'**
  String get createWalletDescription;

  /// No description provided for @createWalletRestoreExistingDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter an existing Monero recovery phrase'**
  String get createWalletRestoreExistingDesc;

  /// No description provided for @createWalletCreateNewDesc.
  ///
  /// In en, this message translates to:
  /// **'Skylight Wallet generates a new Polyseed recovery phrase'**
  String get createWalletCreateNewDesc;

  /// No description provided for @generateSeedSubtitleCovered.
  ///
  /// In en, this message translates to:
  /// **'These words, in this order, are your wallet. Write them down and keep them in a physical safe. If you lose these words or if you share them with anyone else, you will lose your money permanently. Careful planning now avoids a potential disaster later.'**
  String get generateSeedSubtitleCovered;

  /// No description provided for @onboardingConnectionNoteServer.
  ///
  /// In en, this message translates to:
  /// **'Use a light-wallet server (LWS) or your own Monero node.'**
  String get onboardingConnectionNoteServer;

  /// No description provided for @onboardingConnectionNoteChangeable.
  ///
  /// In en, this message translates to:
  /// **'You can change this later in Settings.'**
  String get onboardingConnectionNoteChangeable;

  /// No description provided for @lwsDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet Details'**
  String get lwsDetailsTitle;

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

  /// No description provided for @restoreWalletDescription.
  ///
  /// In en, this message translates to:
  /// **'Input your Monero recovery phrase below. We will check common formats.'**
  String get restoreWalletDescription;

  /// No description provided for @restoreScanDescription.
  ///
  /// In en, this message translates to:
  /// **'Skylight Wallet can skip irrelevant history to save you time. Either pick the first month that you used the wallet or select I\'m not sure to check everything. It\'s okay to pick a month that is too early, but it\'s bad to pick a month that is too late.'**
  String get restoreScanDescription;

  /// No description provided for @restoreWalletInvalidMnemonic.
  ///
  /// In en, this message translates to:
  /// **'Invalid recovery phrase.'**
  String get restoreWalletInvalidMnemonic;

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

  /// No description provided for @navigationBarWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get navigationBarWallet;

  /// History filter: transactions received at, or sent to, one address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get historyFilterAddress;

  /// No description provided for @historyFilterAddressAny.
  ///
  /// In en, this message translates to:
  /// **'Any Address'**
  String get historyFilterAddressAny;

  /// No description provided for @historyFilterAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Transactions received at this address, or sent to it.'**
  String get historyFilterAddressHint;

  /// No description provided for @historyFilterAddressInvalid.
  ///
  /// In en, this message translates to:
  /// **'Not a Monero address'**
  String get historyFilterAddressInvalid;

  /// No description provided for @unlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock Wallet'**
  String get unlockTitle;

  /// No description provided for @homeDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get homeDisconnected;

  /// No description provided for @receiveQrHint.
  ///
  /// In en, this message translates to:
  /// **'Scan this code to send Monero to this wallet.'**
  String get receiveQrHint;

  /// No description provided for @sendInvalidAddressError.
  ///
  /// In en, this message translates to:
  /// **'Invalid address.'**
  String get sendInvalidAddressError;

  /// No description provided for @syncFrequencySheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How often Monero syncs while the app is closed.'**
  String get syncFrequencySheetSubtitle;

  /// No description provided for @syncFrequencyContinuousDesc.
  ///
  /// In en, this message translates to:
  /// **'Continuously sync Monero in the background so it\'s always up to date when you open the app. Uses more battery and requires a persistent notification.'**
  String get syncFrequencyContinuousDesc;

  /// No description provided for @syncFrequencyPeriodicDesc.
  ///
  /// In en, this message translates to:
  /// **'Periodically sync Monero in the background so it\'s usually up to date when you open the app. With a Monero node, it only syncs while charging and on WiFi.'**
  String get syncFrequencyPeriodicDesc;

  /// No description provided for @syncFrequencyPeriodicDescIos.
  ///
  /// In en, this message translates to:
  /// **'Periodically sync Monero in the background so it\'s usually up to date when you open the app. With a Monero node, it only syncs while charging.'**
  String get syncFrequencyPeriodicDescIos;

  /// No description provided for @settingsThemeLightDesc.
  ///
  /// In en, this message translates to:
  /// **'Light and clean'**
  String get settingsThemeLightDesc;

  /// No description provided for @settingsLwsViewKeysLabel.
  ///
  /// In en, this message translates to:
  /// **'LWS View Keys'**
  String get settingsLwsViewKeysLabel;

  /// No description provided for @settingsSecretKeysLabel.
  ///
  /// In en, this message translates to:
  /// **'Secret Restore Keys'**
  String get settingsSecretKeysLabel;

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

  /// No description provided for @secretKeysTitle.
  ///
  /// In en, this message translates to:
  /// **'Secret Restore Keys'**
  String get secretKeysTitle;

  /// No description provided for @secretKeysDescription.
  ///
  /// In en, this message translates to:
  /// **'These recovery phrases and keys restore full control of your wallet. Anyone who sees them can spend your funds.'**
  String get secretKeysDescription;

  /// No description provided for @secretKeysMnemonic.
  ///
  /// In en, this message translates to:
  /// **'Recovery Phrase'**
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

  /// No description provided for @sendIrreversibleNote.
  ///
  /// In en, this message translates to:
  /// **'Transactions are irreversible, so make sure the address and amount are correct.'**
  String get sendIrreversibleNote;

  /// No description provided for @torChoiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tor can hide your IP address from servers you connect to. This does not reduce the information that is stored on public blockchains. In general, how do you want Skylight Wallet to handle Tor connections?'**
  String get torChoiceSubtitle;

  /// Tor Settings sheet description, under its title. Sentence case. Spice's says every chain; Skylight has one wallet.
  ///
  /// In en, this message translates to:
  /// **'Tor can hide your IP address from servers you connect to. This does not reduce the information that is stored on public blockchains. Changing this reconnects your wallet.'**
  String get torSettingsSheetSubtitle;
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
