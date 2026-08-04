import 'package:skylight_wallet/models/wallet_model.dart';
import 'package:skylight_wallet/consts.dart' as consts;

/// How many announced transaction hashes are remembered. The cutoff covers
/// everything older, so this only has to span transactions near the tip.
const int maxRememberedTxHashes = 50;

/// What to announce, and the state to persist afterwards.
class TxNotificationDecision {
  /// Incoming transactions to announce, oldest first.
  final List<TxDetails> toAnnounce;

  /// New value for the cutoff (unix seconds).
  final int cutoff;

  /// New list of remembered hashes, oldest first.
  final List<String> announcedHashes;

  const TxNotificationDecision({
    required this.toAnnounce,
    required this.cutoff,
    required this.announcedHashes,
  });
}

/// Works out which incoming transactions the user hasn't been told about.
///
/// Two pieces of state, because neither is enough alone:
///
/// [cutoff] is a coarse "everything before this is old news" line. It stops a
/// restored wallet — or one that had notifications switched off for a while —
/// from announcing a backlog, and it bounds how much has to be remembered.
///
/// [announcedHashes] catches what a timestamp cannot. A transaction's timestamp
/// is the time it was *seen* while it sits in the mempool and the *block's*
/// timestamp once it is mined, so it moves — usually forward, sometimes
/// backwards — and a payment announced from the mempool would be announced
/// again on confirmation. The same applies to a transaction that is dropped or
/// reorged out and later reappears.
///
/// Only confirmed transactions advance the cutoff. An unconfirmed one carries
/// roughly the current time, which can sit well ahead of blocks the wallet is
/// still scanning; moving the cutoff there would silence whatever those blocks
/// turn up.
TxNotificationDecision decideTxNotifications({
  required List<TxDetails> txHistory,
  required int cutoff,
  required List<String> announcedHashes,
  int maxHashes = maxRememberedTxHashes,
}) {
  final seen = announcedHashes.toSet();

  final toAnnounce =
      txHistory
          .where(
            (tx) =>
                tx.direction == consts.txDirectionIncoming &&
                tx.timestamp > cutoff &&
                !seen.contains(tx.hash),
          )
          .toList()
        // Oldest first, so a burst is announced in the order it happened.
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  var newCutoff = cutoff;

  for (final tx in txHistory) {
    if (isConfirmedTx(tx) && tx.timestamp > newCutoff) {
      newCutoff = tx.timestamp;
    }
  }

  final hashes = [
    ...announcedHashes.where((hash) => !toAnnounce.any((tx) => tx.hash == hash)),
    ...toAnnounce.map((tx) => tx.hash),
  ];

  return TxNotificationDecision(
    toAnnounce: toAnnounce,
    cutoff: newCutoff,
    announcedHashes: hashes.length > maxHashes ? hashes.sublist(hashes.length - maxHashes) : hashes,
  );
}

/// True when a transaction is in a block. Deliberately strict: treating an
/// unconfirmed transaction as confirmed would drag the cutoff forward and
/// silence real notifications, while the reverse only costs a re-check that
/// [decideTxNotifications] deduplicates by hash anyway.
bool isConfirmedTx(TxDetails tx) => tx.height > 0;
