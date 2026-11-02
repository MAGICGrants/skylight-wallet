import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:skylight_wallet/main.dart' as app;
import 'package:skylight_wallet/models/contact_model.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/wallet_core_glue.dart' show appCoins;
import 'package:wallet_domain/screenshots.dart';
import 'package:wallet_backup/screenshots.dart';
import 'package:wallet_backup_platform/wallet_backup_platform.dart'
    show ICloudLocation, MetadataBackupSetup;
import 'package:wallet_domain/wallet_domain.dart' show WalletManager;
import 'package:wallet_fhse/screenshots.dart';
import 'package:wallet_fhse/security_keys_ui.dart' show AdvancedSecurityScreen;
import 'package:wallet_fiat/wallet_fiat.dart' show FiatRates;
import 'package:wallet_monero/screenshots.dart';

/// The App Store and F-Droid screenshots: the real app on a sample wallet,
/// walked through the screens the listings show.
///
/// Not a test to run on its own. wallet-core's `scripts/store-screenshots.sh`
/// runs it (through scripts/store-screenshots.sh here) and takes each picture
/// [StoreShots.capture] asks for. Nothing reaches a server: the wallet is
/// [SampleMoneroWallet], prices are [FiatRates.fixedRates], and the security
/// keys and the backup are samples that only tell their screens so.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('store screenshots', (tester) async {
    // A test build is a debug build: no DEBUG ribbon, and typing goes straight
    // to the field rather than raising the system keyboard over the screen.
    WidgetsApp.debugAllowBannerOverride = false;
    tester.testTextInput.register();
    FiatRates.fixedRates = const {'XMR': _xmrPrice};
    appCoins = () => [SampleMoneroWallet(_activity())];
    sampleSecurityKeysState = _securityKeys();
    MetadataBackupSetup.serviceForTesting = (locations) => SampleMetadataBackupService(
      locations: locations,
      on: {ICloudLocation.locationId, MetadataBackupSetup.autoBackupLocationId},
      payments: 4,
      contacts: _contacts.length,
      lastSync: _now.subtract(const Duration(minutes: 3)),
    );
    // main() installs the app's own error logger; the test framework needs its
    // own back before a failure reaches it, or the run hangs instead of ending.
    final onError = FlutterError.onError;
    app.main();
    try {
      // Onboarding, from the welcome screen to a restored sample wallet.
      await _tap(tester, find.text('Get Started'));
      await _tap(tester, find.text('No Tor'));
      await _tap(tester, find.text('Continue'));
      await _tap(tester, find.text('Continue'));
      await tester.enterText(find.byType(TextField).first, 'lws.example.com:18090');
      await _tap(tester, find.text('Test Connection'));
      await _waitFor(tester, find.text('Connection works'));
      await _tap(tester, find.text('Continue'));
      await _tap(tester, find.text('Restore Existing Wallet'));
      await Clipboard.setData(const ClipboardData(text: _seed));
      await _tap(tester, find.byTooltip('Paste'));
      await _tap(tester, find.text('Restore').last);
      // No backup to import: the sample wallet starts from its seed alone.
      await _tap(tester, find.text('Skip'));
      await _tap(tester, find.text('Continue'));

      // The wallet, behind Tor, with an address book.
      await _waitFor(tester, find.text('Receive'));
      final context = tester.element(find.text('Receive').first);
      await _useExternalTor(context);
      final manager = Provider.of<WalletManager>(context, listen: false);
      final xmr = manager.getWallet('XMR')!;
      xmr.setConnection(
        address: 'lws.example.com:18090',
        proxyPort: '',
        useTor: true,
        connectionType: 'lws',
      );
      await xmr.persistCurrentConnection();
      await manager.applyConnectionChange('XMR');
      await xmr.load();
      await _addContacts(tester, Provider.of<ContactModel>(context, listen: false), {
        for (final MapEntry(key: name, value: address) in _contacts.entries) name: {'XMR': address},
      });

      // The pictures, in the order the app is walked; scripts/store-screenshots.sh
      // puts them in the listing's order. History first: the home it returns
      // to is a fresh one, whose security checklist reads the settings above.
      await _tap(tester, find.text('History'));
      await _shot(tester, 'history', light: false, dark: true);
      await _tap(tester, find.text('Wallet'));
      await _shot(tester, 'wallet_home', light: false, dark: true);

      await _tap(tester, find.text('Receive'));
      await _waitFor(tester, find.text('Copy Address'));
      await _shot(tester, 'receive');
      await _back(tester);

      await _tap(tester, find.text('Send'));
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), _payee);
      await tester.enterText(fields.at(1), '0.25');
      await _shot(tester, 'send');
      await _back(tester);

      await _tap(tester, find.text('Address Book'));
      await _tap(tester, find.text('Alice'));
      await _shot(tester, 'address_book');

      await _tap(tester, find.text('Settings').last);
      await _tap(tester, find.text('Tor Settings'));
      await _shot(tester, 'tor_settings', light: false, dark: true);
      await _back(tester);
      await _tap(tester, find.text('Connection Settings'));
      await _tap(tester, find.text('Test Connection'));
      await _waitFor(tester, find.text('Connection works'));
      await _shot(tester, 'connection_settings');
      await _back(tester);

      await _open(tester, '/metadata_backup');
      await _shot(tester, 'backup');
      await _back(tester);
      // Not the app's own route: that one asks the device to unlock first.
      await _push(tester, const AdvancedSecurityScreen());
      await _shot(tester, 'advanced_security');
      await _back(tester);
    } catch (_) {
      // Where it stopped, for whoever runs this next: the screen, as the
      // script's <device>-failure.png, and the text on it.
      final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data);
      debugPrint('store shots: stopped on: ${texts.nonNulls.join(' | ')}');
      await StoreShots.capture('_failure');
      rethrow;
    } finally {
      FlutterError.onError = onError;
    }
  });
}

// ----- The sample wallet -----

/// A throwaway wallet made for these pictures. It never held funds, and its
/// recovery phrase is public on purpose: it is in this file.
const _seed =
    'glass work jacket reason gas hat question eagle surround airport '
    'document whale dwarf roast wealth immune';

const _xmrPrice = 521.38;

/// Addresses of keys made for these pictures and thrown away: valid, and
/// unspendable by anyone.
const _contacts = {
  'Alice': '45JEhQFx1on7V9yXvTbmXfKJw9VyqDeW8N9YqtbbqimLPV89PJiocbSaUg8FyoUbktQ7c7YGHCgNzNY8Y9BWNEucD933fzZ',
  'Bob': '43cda4NMuFkcnhxHQd4h9VDTfPCBER8tkNoTPtKFrx27YwnSZJYJG7pEZm2moL1wyCCaW37nhXbYLPrBQoDDrMrNKCBVnjZ',
  'Charlie': '44GxkeKtSiiFSNk5WXA2qdRdwEugoDJwsKGFZz9ERGNSWR8HtmVLwEeZYNyeuo2Cg45AwMsGKiD5g9V6rTnacgnn1hC7QNA',
  'David': '41tDUaQwyAgTStMK4JRpPBEHRW8EFnYBu5q9QnvLroTVQpVX432zho58VSRrwAYW7haS46rcnwFPg4yJQVpatUzPTmT6hhd',
  'Eve': '4B1e8NPHWbaKShBH4hGeqEK8TwLJBrh1eGWYVeEff985XLgQQLKt87aVcFEdpgXJ8mQaQNZBNjcmPAdvb9zpPSk8AS9xwNM',
};
const _payee =
    '461qQuRxsfjAJawskpPKqo7qhBtZdm7uMXzca8U2Cp8gTz6D8fqG1HWJPqn4Y91jNL7fAbX8XjgR3LCJcoxCha1HVVf8K7T';

/// 9:41 today, the time the status bar shows.
DateTime get _now {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 9, 41);
}

/// Two security keys set up three weeks ago, as Advanced Security shows them.
/// Nothing is set up: only the screen is told so.
SecurityKeysState _securityKeys() {
  final added = _now.subtract(const Duration(days: 21));
  return SecurityKeysState(
    available: true,
    engaged: true,
    keys: [
      SecurityKeyRecord(id: 'sample-1', name: 'YubiKey 5C NFC', addedAt: added, serial: 28417035),
      SecurityKeyRecord(id: 'sample-2', name: 'Backup key', addedAt: added, serial: 28417291),
    ],
  );
}

SampleActivity _activity() {
  return SampleActivity(
    decimals: 12,
    price: _xmrPrice,
    balance: '8.2394',
    fee: '0.00003074',
    height: 3790200,
    blockTime: const Duration(minutes: 2),
    counterparty: _contacts['Alice']!,
    now: _now,
    txs: const [
      SampleTx(daysAgo: 0, at: (9, 34), incoming: true, fiat: 182, confirmations: 3),
      SampleTx(daysAgo: 1, at: (18, 29), incoming: false, fiat: 47.5),
      SampleTx(daysAgo: 4, at: (13, 52), incoming: true, fiat: 128),
      SampleTx(daysAgo: 9, at: (11, 7), incoming: false, fiat: 12.75),
      SampleTx(daysAgo: 16, at: (16, 45), incoming: true, fiat: 199),
      SampleTx(daysAgo: 29, at: (10, 18), incoming: false, fiat: 310),
      SampleTx(daysAgo: 43, at: (15, 26), incoming: true, fiat: 1250),
      SampleTx(daysAgo: 61, at: (12, 3), incoming: true, fiat: 2400),
      SampleTx(daysAgo: 78, at: (19, 40), incoming: false, fiat: 85),
    ],
  );
}

// ----- Driving the app -----

/// Adds [book] to the address book, once the model's own first read of the
/// stored (empty) book is over: one that lands after an add drops it.
Future<void> _addContacts(
  WidgetTester tester,
  ContactModel contacts,
  Map<String, Map<String, String>> book,
) async {
  await _settle(tester, const Duration(seconds: 2));
  await contacts.load();
  for (final MapEntry(key: name, value: addresses) in book.entries) {
    await contacts.addContact(name, addresses);
  }
  final missing = book.keys.where((name) => !contacts.contacts.any((c) => c.name == name));
  if (missing.isNotEmpty) throw StateError('Contacts not saved: ${missing.join(', ')}');
}

/// Tor as the listing shows it: the user's own (External, port 9050) for prices
/// and the server. Written straight into the saved settings, because the Tor
/// screens test that Tor first, and here there is none; nothing goes through it.
Future<void> _useExternalTor(BuildContext context) async {
  await TorSettingsService.sharedInstance.save(torMode: TorMode.external, socksPort: '9050');
  await FiatRateModel.saveFiatApiMode(FiatApiMode.torOnly);
  if (!context.mounted) return;
  await Provider.of<FiatRateModel>(context, listen: false).startService();
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) throw StateError('Never appeared: $finder');
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _settle(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await _settle(tester, const Duration(milliseconds: 300));
  await tester.tap(finder.first);
  await _settle(tester, const Duration(milliseconds: 800));
}

Future<void> _open(WidgetTester tester, String route) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pushNamed(route);
  await _settle(tester, const Duration(milliseconds: 1200));
}

Future<void> _push(WidgetTester tester, Widget screen) async {
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .push(MaterialPageRoute<void>(builder: (_) => screen));
  await _settle(tester, const Duration(milliseconds: 1200));
}

Future<void> _back(WidgetTester tester) async {
  await tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
  await _settle(tester, const Duration(milliseconds: 800));
}

/// Waits for the screen to come to rest, then has the host take it.
Future<void> _shot(WidgetTester tester, String name, {bool light = true, bool dark = false}) async {
  // No blinking cursor in a field just typed into.
  FocusManager.instance.primaryFocus?.unfocus();
  await _settle(tester, const Duration(milliseconds: 1500));
  debugPrint('store shots: $name');
  await StoreShots.capture(name, light: light, dark: dark);
}
