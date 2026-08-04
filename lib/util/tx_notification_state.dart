import 'dart:convert';

import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/secure_storage.dart';

/// Record of which incoming transactions the user has already been told about.
///
/// Held in secure storage rather than shared preferences. Shared preferences is
/// a plaintext file in the app's private directory, and these are real on-chain
/// identifiers — a readable list of them ties this device to those exact
/// transactions for anyone who gets at the app's files.
class TxNotificationState {
  const TxNotificationState({required this.cutoff, required this.announcedHashes});

  /// Unix seconds of the newest transaction already accounted for. Null when
  /// nothing has been recorded yet: a fresh install, or an upgrade from a build
  /// that tracked a plain transaction count.
  final int? cutoff;

  /// Recently announced transaction hashes, oldest first.
  final List<String> announcedHashes;

  static const empty = TxNotificationState(cutoff: null, announcedHashes: []);
}

const _storageKey = 'txNotificationState';

/// Reads the stored state, or [TxNotificationState.empty] if there is none.
///
/// A failure here reads as "nothing recorded", which makes the caller reseed
/// from the current chain. That direction is deliberate: the alternative to
/// staying quiet is announcing a whole history at once.
Future<TxNotificationState> readTxNotificationState() async {
  try {
    final stored = await secureStorage.read(key: _storageKey);

    if (stored == null || stored.isEmpty) return TxNotificationState.empty;

    final decoded = json.decode(stored) as Map<String, dynamic>;

    return TxNotificationState(
      cutoff: decoded['cutoff'] as int?,
      announcedHashes: (decoded['announcedHashes'] as List<dynamic>? ?? const []).cast<String>(),
    );
  } catch (e) {
    log(LogLevel.warn, 'Could not read transaction notification state: $e');
    return TxNotificationState.empty;
  }
}

Future<void> writeTxNotificationState(TxNotificationState state) async {
  try {
    await secureStorage.write(
      key: _storageKey,
      value: json.encode({'cutoff': state.cutoff, 'announcedHashes': state.announcedHashes}),
    );
  } catch (e) {
    log(LogLevel.warn, 'Could not save transaction notification state: $e');
  }
}

Future<void> clearTxNotificationState() async {
  try {
    await secureStorage.delete(key: _storageKey);
  } catch (e) {
    log(LogLevel.warn, 'Could not clear transaction notification state: $e');
  }
}
