// Desktop Send keeps a contact's name on that contact's own address only (MAGIC
// Grants AI audit 2026-10-20, M-03). The desktop form keeps Paste beside the
// contact card, and pressing it used to leave the contact's name over the
// clipboard's address, through to the confirm sheet, while the tx paid the
// clipboard's address.
//
// Runs where the desktop form does: a Linux, macOS or Windows host
// (`isDesktopLayout`). Nothing leaves the machine: the Monero wallet is
// wallet-core's FakeMoneroBackend and the clipboard is a mocked platform call.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wallet_domain/wallet_domain.dart';
import 'package:wallet_infra/testing.dart';
import 'package:wallet_infra/wallet_infra.dart';
import 'package:wallet_monero/wallet_monero.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/screens/send.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart'
    show BrandButton, ConfirmSendView, SendAmountCard;

void main() {
  late Directory tmp;
  late FakeMoneroBackend backend;
  late WalletManager manager;
  late ContactModel contacts;

  // Stand-ins for Monero addresses (this backend's validator accepts any 95
  // characters starting with '4').
  final alice = '4${'A' * 94}';
  final pasted = '4${'Z' * 94}';
  final aliceContact = Contact(id: 'c1', name: 'Alice', addresses: {'XMR': alice});

  final onDesktop = Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  setUpAll(() => WalletFileCrypto.kdf = const FastTestPbkdf2());
  tearDownAll(() => WalletFileCrypto.kdf = const WebCryptoPbkdf2());

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('send_contact_paste');
    SharedPreferencesService.store = MemoryPreferenceStore();
    WalletSecrets.store = MemorySecretStore();
    WalletAppConfig.install(WalletAppConfig.skylight, directories: FixedDirectories(tmp));
    useTestCaBundle();
    WalletLog.sink = MemoryLogSink();
    backend = FakeMoneroBackend()
      ..addressValidator = ((a, _) => a.length == 95 && a.startsWith('4'));
    final wallet = MoneroWallet(backend: backend);
    backend.existingWalletPaths.add(await wallet.walletPathForType('lws'));
    await wallet.openExisting(password: 'pw');
    // 10 XMR spendable, so the form can be submitted.
    // ignore: invalid_use_of_protected_member
    wallet.setUnlockedBalanceBaseUnits(BigInt.from(10) * BigInt.from(10).pow(12));
    backend.pendingAmount = BigInt.from(10).pow(12);
    backend.pendingFee = BigInt.from(30000000);
    manager = WalletManager(coins: () => [wallet]);
    contacts = ContactModel(
      read: () async => [json.encode(aliceContact.toJson())],
      write: (_) async {},
    );
    await contacts.load();
  });

  tearDown(() {
    WalletAppConfig.resetForTesting();
    CaBundle.resetForTesting();
    SharedPreferencesService.resetForTesting();
    tmp.deleteSync(recursive: true);
  });

  String short(String a) => '${a.substring(0, 10)}…${a.substring(a.length - 12)}';

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Opens Send; with [args], as the address book's Send opens it.
  Future<void> openSend(WidgetTester tester, {SendScreenArgs? args}) async {
    // The clipboard holds an address the user did not mean (or a clipboard
    // hijacker put there).
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.getData') return <String, dynamic>{'text': pasted};
      return null;
    });

    // The test font (Ahem) is wider than the app's, so the fixed-width desktop
    // sidebar overflows; that layout warning is not what these tests are about.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) return;
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletManager>.value(value: manager),
          ChangeNotifierProvider<ContactModel>.value(value: contacts),
          ChangeNotifierProvider<FiatRateModel>(create: (_) => FiatRateModel()),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateRoute: (settings) => MaterialPageRoute(
            settings: RouteSettings(name: '/send', arguments: args),
            builder: (_) => const SendScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(SendScreen)))!;

  /// Picks Alice in Send's own contact picker.
  Future<void> pickAlice(WidgetTester tester) async {
    await tester.tap(find.text(l10n(tester).sendContactsButton));
    await settle(tester);
    await tester.tap(find.text('Alice'));
    await settle(tester);
  }

  /// Enters 1 XMR and presses Send, which opens the confirm sheet.
  Future<void> sendOneXmr(WidgetTester tester) async {
    await tester.enterText(
      find.descendant(of: find.byType(SendAmountCard), matching: find.byType(TextField)),
      '1',
    );
    await settle(tester);
    final sendButton = find.widgetWithText(BrandButton, l10n(tester).sendSendButton);
    expect(sendButton, findsOneWidget);
    await tester.tap(sendButton);
    await settle(tester);
    expect(find.byType(ConfirmSendView), findsOneWidget);
  }

  Finder onConfirmSheet(Finder finder) =>
      find.descendant(of: find.byType(ConfirmSendView), matching: finder);

  Future<void> tearDownScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  for (final viaPicker in [false, true]) {
    final how = viaPicker ? "Send's contact picker" : "the address book's Send";
    testWidgets('Paste after a contact from $how replaces the contact', (tester) async {
      await openSend(
        tester,
        args: viaPicker ? null : SendScreenArgs(destinationAddress: alice, contact: aliceContact),
      );
      if (viaPicker) await pickAlice(tester);

      // Before: the contact card names Alice over her address, with Paste beside it.
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text(short(alice)), findsOneWidget);
      final paste = find.text(l10n(tester).sendPasteButton);
      expect(paste, findsOneWidget);

      await tester.tap(paste);
      await tester.pump(const Duration(milliseconds: 100));

      // After: the contact is gone and the card is the address field again,
      // holding the clipboard's address.
      expect(find.text('Alice'), findsNothing);
      expect(find.text(short(alice)), findsNothing);
      final addressField = find
          .byType(TextField)
          .evaluate()
          .map((e) => e.widget as TextField)
          .where((f) => f.controller?.text == pasted);
      expect(addressField, hasLength(1));

      await sendOneXmr(tester);

      // The tx pays the clipboard's address, and the confirm sheet shows that
      // address without the contact's name.
      expect(backend.createTransactionRequests.last.destinations, [pasted]);
      expect(onConfirmSheet(find.text(pasted, findRichText: true)), findsOneWidget);
      expect(onConfirmSheet(find.textContaining('Alice')), findsNothing);
      expect(find.text('(Alice)'), findsNothing);

      await tearDownScreen(tester);
    }, skip: !onDesktop);
  }

  testWidgets('a contact with nothing pasted still names its address on the confirm sheet', (
    tester,
  ) async {
    await openSend(
      tester,
      args: SendScreenArgs(destinationAddress: alice, contact: aliceContact),
    );
    expect(find.text('Alice'), findsOneWidget);

    await sendOneXmr(tester);

    expect(backend.createTransactionRequests.last.destinations, [alice]);
    expect(onConfirmSheet(find.text(alice, findRichText: true)), findsOneWidget);
    expect(onConfirmSheet(find.text('(Alice)')), findsOneWidget);

    await tearDownScreen(tester);
  }, skip: !onDesktop);

  testWidgets('a contact handed in with an address that is not theirs is not shown', (
    tester,
  ) async {
    // The contact arrives after the text, so the field's listener never sees it.
    await openSend(
      tester,
      args: SendScreenArgs(destinationAddress: pasted, contact: aliceContact),
    );
    expect(find.text('Alice'), findsNothing);

    await sendOneXmr(tester);

    expect(backend.createTransactionRequests.last.destinations, [pasted]);
    expect(find.text('(Alice)'), findsNothing);

    await tearDownScreen(tester);
  }, skip: !onDesktop);
}
