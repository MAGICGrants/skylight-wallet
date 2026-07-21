import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:spice_wallet/util/socks_http.dart';
import 'package:spice_wallet/util/socks_socket.dart';

/// One transaction from a Blockscout v2 `addresses/{hash}/transactions`
/// response.
class ExplorerTx {
  ExplorerTx({
    required this.hash,
    required this.from,
    required this.to,
    required this.valueWei,
    required this.feeWei,
    required this.blockNumber,
    required this.status,
    required this.timestamp,
  });

  final String hash;
  final String from;
  final String to;
  final BigInt valueWei;
  final BigInt feeWei;
  final int blockNumber;
  final int status; // 1 success, 0 failed
  final int timestamp; // unix seconds
}

/// Fetches address history from a user-supplied Blockscout instance via its
/// native v2 API (`/api/v2/addresses/{hash}/transactions`). Routes through Tor
/// (SOCKS) when a port is given — using the Content-Length-aware
/// [SOCKSSocket.sendHttpRequest] since history can be large — otherwise a
/// direct [HttpClient]. Returns the first (most recent) page.
class EthereumExplorerClient {
  Future<List<ExplorerTx>> fetchTxList(String baseUrl, String address, {int? socksPort}) async {
    final normalizedBase = _normalizeBase(baseUrl);
    final url = '$normalizedBase/api/v2/addresses/$address/transactions';

    final json = await _getJson(url, socksPort);
    final items = json is Map ? json['items'] : null;
    if (items is! List) return const [];

    final out = <ExplorerTx>[];
    for (final t in items) {
      if (t is! Map) continue;
      final hash = t['hash'] as String?;
      if (hash == null) continue;
      final from = t['from'] is Map ? (t['from']['hash'] as String?) ?? '' : '';
      final to = t['to'] is Map ? (t['to']['hash'] as String?) ?? '' : '';
      final fee = t['fee'] is Map ? '${t['fee']['value']}' : '0';
      out.add(
        ExplorerTx(
          hash: hash,
          from: from,
          to: to,
          valueWei: BigInt.tryParse('${t['value']}') ?? BigInt.zero,
          feeWei: BigInt.tryParse(fee) ?? BigInt.zero,
          blockNumber: (t['block_number'] as num?)?.toInt() ?? 0,
          status: t['status'] == 'ok' ? 1 : 0,
          timestamp: _parseTimestamp(t['timestamp']),
        ),
      );
    }
    return out;
  }

  /// Fetches ERC-20 transfers for [address] involving the token at
  /// [contractAddress] (Blockscout v2 `addresses/{hash}/token-transfers`).
  /// The token amount is carried in `valueWei` (raw, token-decimal units);
  /// `feeWei` is 0 (gas fee belongs to the parent tx, known only locally for
  /// our own outgoing transfers).
  Future<List<ExplorerTx>> fetchTokenTransfers(
    String baseUrl,
    String address,
    String contractAddress, {
    int? socksPort,
  }) async {
    final normalizedBase = _normalizeBase(baseUrl);
    final url = '$normalizedBase/api/v2/addresses/$address/token-transfers?type=ERC-20';
    final contract = contractAddress.toLowerCase();

    final json = await _getJson(url, socksPort);
    final items = json is Map ? json['items'] : null;
    if (items is! List) return const [];

    final out = <ExplorerTx>[];
    for (final t in items) {
      if (t is! Map) continue;
      final token = t['token'];
      final tokenAddr = token is Map
          ? '${token['address'] ?? token['address_hash'] ?? ''}'.toLowerCase()
          : '';
      if (tokenAddr != contract) continue;
      final hash = (t['transaction_hash'] ?? t['tx_hash']) as String?;
      if (hash == null) continue;
      final from = t['from'] is Map ? (t['from']['hash'] as String?) ?? '' : '';
      final to = t['to'] is Map ? (t['to']['hash'] as String?) ?? '' : '';
      final total = t['total'];
      final value = total is Map ? '${total['value']}' : '0';
      out.add(
        ExplorerTx(
          hash: hash,
          from: from,
          to: to,
          valueWei: BigInt.tryParse(value) ?? BigInt.zero,
          feeWei: BigInt.zero,
          blockNumber: (t['block_number'] as num?)?.toInt() ?? 0,
          status: 1,
          timestamp: _parseTimestamp(t['timestamp']),
        ),
      );
    }
    return out;
  }

  /// Verifies the endpoint is a Blockscout v2 instance via its lightweight
  /// `/api/v2/stats` endpoint (a small JSON object with Blockscout-specific
  /// fields). Throws otherwise.
  Future<void> probe(String baseUrl, {int? socksPort}) async {
    final normalizedBase = _normalizeBase(baseUrl);
    final json = await _getJson('$normalizedBase/api/v2/stats', socksPort);
    if (json is! Map || json['total_blocks'] == null) {
      throw Exception('Not a Blockscout v2 explorer (unexpected response).');
    }
  }

  /// Normalizes a user-entered base to the host root: adds https if missing,
  /// strips a trailing slash and any `/api` or `/api/v2` they may have pasted.
  String _normalizeBase(String baseUrl) {
    final raw = baseUrl.trim();
    var b = (raw.startsWith('http://') || raw.startsWith('https://')) ? raw : 'https://$raw';
    b = b.replaceAll(RegExp(r'/+$'), '');
    b = b.replaceAll(RegExp(r'/api(/v2)?$'), '');
    return b;
  }

  int _parseTimestamp(dynamic iso) {
    if (iso is! String) return 0;
    final dt = DateTime.tryParse(iso);
    return dt != null ? dt.millisecondsSinceEpoch ~/ 1000 : 0;
  }

  static const Duration _timeout = Duration(seconds: 30);

  Future<dynamic> _getJson(String url, int? socksPort) async {
    if (socksPort != null && socksPort > 0) {
      final uri = Uri.parse(url);
      final socket = await SOCKSSocket.create(
        proxyHost: InternetAddress.loopbackIPv4.address,
        proxyPort: socksPort,
        sslEnabled: uri.scheme == 'https',
      );
      try {
        await socket.connect().timeout(_timeout);
        await socket.connectTo(uri.host, uri.port).timeout(_timeout);
        final raw = await socket
            .sendHttpRequest(getRawHttpRequestString('GET', url))
            .timeout(_timeout);
        return parseHttpResponse(raw).jsonBody;
      } finally {
        // Fire-and-forget: close() can block on flush/cancel and must not stall
        // the result (the RPC path never closes at all).
        unawaited(socket.close().catchError((_) {}));
      }
    }
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url)).timeout(_timeout);
      final resp = await req.close().timeout(_timeout);
      final text = await resp.transform(utf8.decoder).join().timeout(_timeout);
      return jsonDecode(text);
    } finally {
      client.close(force: true);
    }
  }
}
