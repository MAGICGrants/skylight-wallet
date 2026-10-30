// TorService lives in wallet-core (wallet_infra); kept under this path so call
// sites are unchanged. The copy that used to live here was the same logic with
// a duplicated log line and a non-null-asserted `_tor!` in `disable()`.
export 'package:wallet_infra/wallet_infra.dart' show TorService, TorConnectionStatus;
