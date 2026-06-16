import 'dart:convert';
import 'dart:io';

import 'package:skylight_wallet/util/socks_http.dart';
import 'package:skylight_wallet/util/socks_socket.dart';

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
  Future<List<ExplorerTx>> fetchTxList(
    String baseUrl,
    String address, {
    int? socksPort,
  }) async {
    final base = _normalizeBase(baseUrl);
    final url = '$base/api/v2/addresses/$address/transactions';

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

  Future<dynamic> _getJson(String url, int? socksPort) async {
    if (socksPort != null && socksPort > 0) {
      final uri = Uri.parse(url);
      final socket = await SOCKSSocket.create(
        proxyHost: InternetAddress.loopbackIPv4.address,
        proxyPort: socksPort,
        sslEnabled: uri.scheme == 'https',
      );
      try {
        await socket.connect();
        await socket.connectTo(uri.host, uri.port);
        final raw = await socket.sendHttpRequest(getRawHttpRequestString('GET', url));
        return parseHttpResponse(raw).jsonBody;
      } finally {
        await socket.close();
      }
    }
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();
      final text = await resp.transform(utf8.decoder).join();
      return jsonDecode(text);
    } finally {
      client.close(force: true);
    }
  }
}
