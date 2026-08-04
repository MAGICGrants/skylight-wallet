import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skylight_wallet/models/wallet_model.dart';
import 'package:skylight_wallet/util/tx_notification_state.dart';

/// Covers the persisted side of the notification marker: that it lives in
/// secure storage, that it seeds rather than announcing a backlog, and that a
/// build upgrading from the old plaintext counter starts clean.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'notificationsEnabled': true});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<Map<String, dynamic>?> storedState() async {
    final raw = await const FlutterSecureStorage().read(key: 'txNotificationState');
    return raw == null ? null : json.decode(raw) as Map<String, dynamic>;
  }

  test('nothing about announced transactions is written to shared preferences', () async {
    await WalletModel().markExistingTxsAsNotified();

    // These are on-chain identifiers; they must not land in the plaintext
    // preferences file alongside the theme and language settings.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), ['notificationsEnabled']);
    expect(await storedState(), isNotNull);
  });

  test('markExistingTxsAsNotified seeds the cutoff to now and clears the hashes', () async {
    FlutterSecureStorage.setMockInitialValues({
      'txNotificationState': json.encode({
        'cutoff': 10,
        'announcedHashes': ['stale'],
      }),
    });

    final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await WalletModel().markExistingTxsAsNotified();
    final after = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final state = await storedState();
    expect(state!['cutoff'], greaterThanOrEqualTo(before));
    expect(state['cutoff'], lessThanOrEqualTo(after));
    expect(state['announcedHashes'], isEmpty);
  });

  test('the first run with no marker seeds instead of announcing a backlog', () async {
    // What an upgrade from the old count-based marker looks like: notifications
    // switched on, nothing recorded about what has been announced.
    expect(await readTxNotificationState().then((s) => s.cutoff), isNull);

    await WalletModel().notifyNewIncomingTxs();

    // Seeded, so the next run compares against now rather than the epoch. If
    // this regressed, a wallet with history would announce all of it at once.
    expect((await storedState())!['cutoff'], isNotNull);
  });

  test('a seeded marker is left alone when there is nothing new', () async {
    FlutterSecureStorage.setMockInitialValues({
      'txNotificationState': json.encode({
        'cutoff': 1234,
        'announcedHashes': ['a'],
      }),
    });

    await WalletModel().notifyNewIncomingTxs();

    final state = await storedState();
    expect(state!['cutoff'], 1234);
    expect(state['announcedHashes'], ['a']);
  });

  test('an unreadable entry reseeds rather than throwing or announcing', () async {
    FlutterSecureStorage.setMockInitialValues({'txNotificationState': 'not json'});

    expect((await readTxNotificationState()).cutoff, isNull);
    await expectLater(WalletModel().notifyNewIncomingTxs(), completes);
    expect((await storedState())!['cutoff'], isNotNull);
  });

  test('state survives a round trip', () async {
    await writeTxNotificationState(
      const TxNotificationState(cutoff: 42, announcedHashes: ['a', 'b']),
    );

    final read = await readTxNotificationState();
    expect(read.cutoff, 42);
    expect(read.announcedHashes, ['a', 'b']);

    await clearTxNotificationState();
    expect((await readTxNotificationState()).cutoff, isNull);
  });
}
