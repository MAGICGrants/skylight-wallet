import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_infra/wallet_infra.dart';

// TorService lives in wallet-core (wallet_infra); kept under this path so call
// sites are unchanged. The copy that used to live here was the same logic with
// a duplicated log line and a non-null-asserted `_tor!` in `disable()`.
export 'package:wallet_infra/wallet_infra.dart' show TorService, TorConnectionStatus;

/// Riverpod handle for the shared service. Stays app-side: wallet-core does not
/// depend on riverpod, so apps wrap the singleton themselves.
final pTorService = Provider((_) => TorService.sharedInstance);
