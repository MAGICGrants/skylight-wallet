import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:skylight_wallet/util/socks_http.dart';

class EthReceipt {
  EthReceipt({
    required this.blockNumber,
    required this.gasUsed,
    required this.effectiveGasPrice,
    required this.status,
  });
  final int blockNumber;
  final BigInt gasUsed;
  final BigInt effectiveGasPrice;
  final int status; // 1 success, 0 failed, -1 unknown
}

class EthereumRpcException implements Exception {
  EthereumRpcException(this.message);
  final String message;
  @override
  String toString() => 'EthereumRpcException: $message';
}

/// Minimal Ethereum JSON-RPC client over the app's Tor/clearnet HTTP path.
///
/// Stateless: every call is an HTTP POST. Routes through Tor when a SOCKS port
/// is configured (reusing [makeSocksHttpRequest]), otherwise a direct
/// [HttpClient]. Responses are small, so the truncation caveat of the SOCKS
/// `send` path doesn't apply here (the explorer client handles large bodies).
class EthereumRpcClient {
  EthereumRpcClient({this.coinSymbol});
  final String? coinSymbol;

  String? _url;
  int? _socksPort;
  int _nextId = 0;

  static const Duration _timeout = Duration(seconds: 30);

  void configure({required String url, int? socksPort}) {
    // The connection form strips the scheme (it's built for host:port); RPC
    // URLs need one, so default to https.
    final u = url.trim();
    _url = (u.startsWith('http://') || u.startsWith('https://')) ? u : 'https://$u';
    _socksPort = socksPort;
  }

  bool get isConfigured => _url != null && _url!.isNotEmpty;

  String? get url => _url;

  Future<dynamic> call(String method, List<dynamic> params, {Duration? timeout}) async {
    final url = _url;
    if (url == null || url.isEmpty) {
      throw EthereumRpcException('RPC URL not configured');
    }
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'id': _nextId++,
      'method': method,
      'params': params,
    });
    final decoded = await _post(url, body, timeout ?? _timeout);
    if (decoded is! Map) throw EthereumRpcException('Malformed RPC response');
    final error = decoded['error'];
    if (error != null) {
      final msg = error is Map ? (error['message']?.toString() ?? '$error') : '$error';
      throw EthereumRpcException(msg);
    }
    return decoded['result'];
  }

  Future<dynamic> _post(String url, String body, Duration timeout) async {
    final socksPort = _socksPort;
    if (socksPort != null && socksPort > 0) {
      final resp = await makeSocksHttpRequest(
        'POST',
        url,
        (host: InternetAddress.loopbackIPv4, port: socksPort),
        body: body,
      ).timeout(timeout);
      final json = resp.jsonBody;
      if (json == null) {
        throw EthereumRpcException('Non-JSON response (status ${resp.statusCode})');
      }
      return json;
    }
    return _postDirect(url, body, timeout);
  }

  Future<dynamic> _postDirect(String url, String body, Duration timeout) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse(url)).timeout(timeout);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.write(body);
      final resp = await req.close().timeout(timeout);
      final text = await resp.transform(utf8.decoder).join().timeout(timeout);
      return jsonDecode(text);
    } finally {
      client.close(force: true);
    }
  }

  // ----- Typed helpers -----

  Future<int> chainId() async => _hexToInt(await call('eth_chainId', []));

  Future<int> blockNumber() async => _hexToInt(await call('eth_blockNumber', []));

  Future<BigInt> getBalance(String address) async =>
      _hexToBigInt(await call('eth_getBalance', [address, 'latest']));

  Future<int> getTransactionCount(String address) async =>
      _hexToInt(await call('eth_getTransactionCount', [address, 'pending']));

  /// Base fee of the latest block (EIP-1559). Zero on pre-1559 chains.
  Future<BigInt> baseFeePerGas() async {
    final block = await call('eth_getBlockByNumber', ['latest', false]);
    if (block is Map && block['baseFeePerGas'] != null) {
      return _hexToBigInt(block['baseFeePerGas']);
    }
    return BigInt.zero;
  }

  /// Suggested priority tip; falls back to 1 gwei if the node lacks the method.
  Future<BigInt> maxPriorityFeePerGas() async {
    try {
      return _hexToBigInt(await call('eth_maxPriorityFeePerGas', []));
    } catch (_) {
      return BigInt.from(1000000000);
    }
  }

  Future<BigInt> estimateGas({
    required String from,
    required String to,
    required BigInt value,
    String? data,
  }) async {
    final tx = {'from': from, 'to': to, 'value': '0x${value.toRadixString(16)}'};
    if (data != null && data.isNotEmpty) tx['data'] = data;
    return _hexToBigInt(await call('eth_estimateGas', [tx]));
  }

  /// Read-only contract call (`eth_call`) against [to] with ABI-encoded [data];
  /// returns the raw hex result. Used for ERC-20 reads like `balanceOf`.
  Future<String> ethCall(String to, String data) async {
    final r = await call('eth_call', [
      {'to': to, 'data': data},
      'latest',
    ]);
    if (r is String) return r;
    throw EthereumRpcException('Unexpected eth_call response: $r');
  }

  Future<String> sendRawTransaction(String rawHex) async {
    final r = await call('eth_sendRawTransaction', [rawHex]);
    if (r is String) return r;
    throw EthereumRpcException('Unexpected broadcast response: $r');
  }

  /// Receipt for [hash], or null while the tx is still pending (not mined).
  Future<EthReceipt?> getTransactionReceipt(String hash) async {
    final r = await call('eth_getTransactionReceipt', [hash]);
    if (r is! Map) return null;
    return EthReceipt(
      blockNumber: _hexToInt(r['blockNumber']),
      gasUsed: _hexToBigInt(r['gasUsed']),
      effectiveGasPrice:
          r['effectiveGasPrice'] != null ? _hexToBigInt(r['effectiveGasPrice']) : BigInt.zero,
      status: r['status'] != null ? _hexToInt(r['status']) : -1,
    );
  }

  static int _hexToInt(dynamic hex) => _hexToBigInt(hex).toInt();

  static BigInt _hexToBigInt(dynamic hex) {
    if (hex is! String) throw EthereumRpcException('Expected hex string, got $hex');
    final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
    if (clean.isEmpty) return BigInt.zero;
    return BigInt.parse(clean, radix: 16);
  }
}
