// The SOCKS-over-Tor HTTP client lives in wallet-core (wallet_infra); kept under
// this path so call sites (height lookup, connection test) are unchanged.
export 'package:wallet_infra/wallet_infra.dart' show makeSocksHttpRequest, ParsedHttpResponse;
