import 'package:http/http.dart' as http;

/// An [http.Client] that refuses all network I/O.
///
/// Used to back a `Web3Client` that must only sign transactions offline: if
/// web3dart ever performs a request on it, this fails loudly instead of
/// silently egressing over clearnet and bypassing the app's Tor/SOCKS routing.
class OfflineSigningClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw StateError('Offline signing client must not make network requests (${request.url}).');
  }
}
