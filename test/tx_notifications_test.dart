import 'package:flutter_test/flutter_test.dart';

import 'package:skylight_wallet/consts.dart' as consts;
import 'package:skylight_wallet/models/wallet_model.dart';
import 'package:skylight_wallet/util/tx_notifications.dart';

/// A transaction as the wallet reports it. [height] of -1 means unconfirmed.
TxDetails tx({
  required String hash,
  required int timestamp,
  int direction = consts.txDirectionIncoming,
  int height = 100,
  double amount = 1.5,
}) {
  return TxDetails(
    index: 0,
    direction: direction,
    hash: hash,
    amount: amount,
    fee: 0,
    recipients: const [],
    accountIndex: 0,
    subaddrIndexList: const [0],
    timestamp: timestamp,
    height: height,
    confirmations: height > 0 ? 10 : 0,
    key: '',
  );
}

/// The wallet hands history back newest first.
List<TxDetails> newestFirst(List<TxDetails> txs) =>
    [...txs]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

List<String> hashesOf(List<TxDetails> txs) => txs.map((t) => t.hash).toList();

void main() {
  group('decideTxNotifications', () {
    test('announces an incoming transaction newer than the cutoff', () {
      final decision = decideTxNotifications(
        txHistory: newestFirst([tx(hash: 'a', timestamp: 1000)]),
        cutoff: 500,
        announcedHashes: const [],
      );

      expect(hashesOf(decision.toAnnounce), ['a']);
      expect(decision.cutoff, 1000);
      expect(decision.announcedHashes, ['a']);
    });

    test('ignores outgoing transactions', () {
      final decision = decideTxNotifications(
        txHistory: newestFirst([
          tx(hash: 'out', timestamp: 1000, direction: consts.txDirectionOutgoing),
        ]),
        cutoff: 500,
        announcedHashes: const [],
      );

      expect(decision.toAnnounce, isEmpty);
      // The cutoff still moves: it tracks what has been seen, not what was said.
      expect(decision.cutoff, 1000);
    });

    test('ignores anything at or before the cutoff', () {
      final decision = decideTxNotifications(
        txHistory: newestFirst([
          tx(hash: 'old', timestamp: 400),
          tx(hash: 'exactly-at', timestamp: 500),
        ]),
        cutoff: 500,
        announcedHashes: const [],
      );

      expect(decision.toAnnounce, isEmpty);
      expect(decision.cutoff, 500);
    });

    test('announces a burst oldest first', () {
      final decision = decideTxNotifications(
        txHistory: newestFirst([
          tx(hash: 'c', timestamp: 3000),
          tx(hash: 'a', timestamp: 1000),
          tx(hash: 'b', timestamp: 2000),
        ]),
        cutoff: 500,
        announcedHashes: const [],
      );

      expect(hashesOf(decision.toAnnounce), ['a', 'b', 'c']);
      expect(decision.cutoff, 3000);
    });

    test('a second pass over the same history announces nothing', () {
      final history = newestFirst([tx(hash: 'a', timestamp: 1000)]);

      final first = decideTxNotifications(
        txHistory: history,
        cutoff: 500,
        announcedHashes: const [],
      );
      final second = decideTxNotifications(
        txHistory: history,
        cutoff: first.cutoff,
        announcedHashes: first.announcedHashes,
      );

      expect(second.toAnnounce, isEmpty);
      expect(second.cutoff, first.cutoff);
    });

    test('nothing is announced when the history is empty', () {
      final decision = decideTxNotifications(
        txHistory: const [],
        cutoff: 500,
        announcedHashes: const [],
      );

      expect(decision.toAnnounce, isEmpty);
      expect(decision.cutoff, 500);
    });

    test('the cutoff never moves backwards', () {
      final decision = decideTxNotifications(
        txHistory: newestFirst([tx(hash: 'old', timestamp: 100)]),
        cutoff: 9000,
        announcedHashes: const [],
      );

      expect(decision.cutoff, 9000);
    });
  });

  group('mempool and reorg edge cases', () {
    test('a mempool transaction is announced once, not again when mined', () {
      // Seen unconfirmed at t=1000...
      final unconfirmed = tx(hash: 'a', timestamp: 1000, height: -1);
      final first = decideTxNotifications(
        txHistory: [unconfirmed],
        cutoff: 500,
        announcedHashes: const [],
      );

      expect(hashesOf(first.toAnnounce), ['a']);
      // An unconfirmed transaction must not drag the cutoff forward.
      expect(first.cutoff, 500);

      // ...then mined into a block stamped later than it was seen.
      final mined = tx(hash: 'a', timestamp: 1600, height: 3000);
      final second = decideTxNotifications(
        txHistory: [mined],
        cutoff: first.cutoff,
        announcedHashes: first.announcedHashes,
      );

      expect(second.toAnnounce, isEmpty, reason: 'the hash is remembered');
      expect(second.cutoff, 1600);
    });

    test('a block timestamp earlier than when the tx was seen is still not repeated', () {
      final first = decideTxNotifications(
        txHistory: [tx(hash: 'a', timestamp: 1000, height: -1)],
        cutoff: 500,
        announcedHashes: const [],
      );
      final second = decideTxNotifications(
        // Miner clocks drift; a block can be stamped before the tx was seen.
        txHistory: [tx(hash: 'a', timestamp: 900, height: 3000)],
        cutoff: first.cutoff,
        announcedHashes: first.announcedHashes,
      );

      expect(second.toAnnounce, isEmpty);
    });

    test('a dropped transaction that reappears is not announced twice', () {
      final first = decideTxNotifications(
        txHistory: [tx(hash: 'a', timestamp: 1000, height: -1)],
        cutoff: 500,
        announcedHashes: const [],
      );

      // Dropped from the mempool: gone from history entirely.
      final whileGone = decideTxNotifications(
        txHistory: const [],
        cutoff: first.cutoff,
        announcedHashes: first.announcedHashes,
      );

      // Rebroadcast and mined later.
      final back = decideTxNotifications(
        txHistory: [tx(hash: 'a', timestamp: 5000, height: 3100)],
        cutoff: whileGone.cutoff,
        announcedHashes: whileGone.announcedHashes,
      );

      expect(back.toAnnounce, isEmpty);
    });

    test('a reorged-out transaction is not announced again when it returns', () {
      final first = decideTxNotifications(
        txHistory: [tx(hash: 'a', timestamp: 1000, height: 3000)],
        cutoff: 500,
        announcedHashes: const [],
      );
      expect(hashesOf(first.toAnnounce), ['a']);

      // Reorged out and re-mined in a different block, with a new timestamp.
      final after = decideTxNotifications(
        txHistory: [tx(hash: 'a', timestamp: 1200, height: 3001)],
        cutoff: first.cutoff,
        announcedHashes: first.announcedHashes,
      );

      expect(after.toAnnounce, isEmpty);
    });

    test('an unconfirmed tx does not silence older blocks still being scanned', () {
      // A mempool payment is seen while the scanner is far behind the tip.
      final first = decideTxNotifications(
        txHistory: [tx(hash: 'mempool', timestamp: 9000, height: -1)],
        cutoff: 500,
        announcedHashes: const [],
      );
      expect(first.cutoff, 500, reason: 'unconfirmed must not move the cutoff');

      // The scan then reaches an older block holding another payment.
      final second = decideTxNotifications(
        txHistory: newestFirst([
          tx(hash: 'mempool', timestamp: 9000, height: -1),
          tx(hash: 'older-block', timestamp: 4000, height: 2900),
        ]),
        cutoff: first.cutoff,
        announcedHashes: first.announcedHashes,
      );

      expect(hashesOf(second.toAnnounce), ['older-block']);
    });
  });

  group('remembered hashes', () {
    test('are capped, keeping the most recent', () {
      var cutoff = 0;
      var hashes = <String>[];

      // 10 unconfirmed transactions, so the cutoff never advances and the cap
      // is the only thing keeping the list bounded.
      for (var i = 1; i <= 10; i++) {
        final decision = decideTxNotifications(
          txHistory: [tx(hash: 'tx$i', timestamp: i * 100, height: -1)],
          cutoff: cutoff,
          announcedHashes: hashes,
          maxHashes: 3,
        );
        cutoff = decision.cutoff;
        hashes = decision.announcedHashes;
      }

      expect(hashes, ['tx8', 'tx9', 'tx10']);
    });

    test('a hash is not duplicated when the same tx is re-seen', () {
      final first = decideTxNotifications(
        txHistory: [tx(hash: 'a', timestamp: 1000, height: -1)],
        cutoff: 500,
        announcedHashes: const [],
      );
      final second = decideTxNotifications(
        txHistory: [tx(hash: 'a', timestamp: 1000, height: -1)],
        cutoff: first.cutoff,
        announcedHashes: first.announcedHashes,
      );

      expect(second.announcedHashes, ['a']);
    });
  });

  group('isConfirmedTx', () {
    test('treats -1 and 0 as unconfirmed', () {
      expect(isConfirmedTx(tx(hash: 'a', timestamp: 1, height: -1)), isFalse);
      expect(isConfirmedTx(tx(hash: 'a', timestamp: 1, height: 0)), isFalse);
      expect(isConfirmedTx(tx(hash: 'a', timestamp: 1, height: 1)), isTrue);
    });
  });
}
