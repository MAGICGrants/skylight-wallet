import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/socks_socket.dart';

/// Minimal Electrum JSON-RPC client.
///
/// Adapted (and trimmed) from `cw_bitcoin/lib/electrum.dart`. Only the
/// subset needed for a BIP84 wallet is implemented; everything related
/// to silent payments, lightning, payjoin, MWEB and hardware wallets has
/// been removed.
///
/// Connection modes:
///  - direct TCP, optionally upgraded to TLS (when [useSsl] is true);
///  - SOCKS5 via [SOCKSSocket] when [socksHost]/[socksPort] are set,
///    again optionally upgraded to TLS at the SOCKS endpoint.
class ElectrumClient {
  ElectrumClient({this.coinSymbol});

  /// Coin tag for log lines (e.g. `BTC`, `TBTC`).
  final String? coinSymbol;

  static final Duration _requestTimeout = Duration(seconds: 30);
  static final Duration _aliveInterval = Duration(seconds: 30);

  /// Max number of in-flight pipelined requests for a single [callBatch] call.
  /// Most Electrum servers happily handle 10+ concurrent requests, but a few
  /// (ElectrumX with low `max_concurrent`, lightweight mobile servers) drop
  /// the socket under heavy load. Eight is a conservative sweet spot.
  static const int _pipelineChunk = 8;

  Socket? _plainSocket;
  SOCKSSocket? _socksSocket;
  StreamSubscription<List<int>>? _socketSub;
  Timer? _aliveTimer;

  int _nextId = 0;
  String _buffer = '';
  bool _connected = false;

  /// JSON-RPC 2.0 batch (array) mode. Stays true until a batch frame is
  /// observed to hard-fail before the server ever returned an array reply,
  /// at which point we fall back to pipelined per-request frames for the
  /// life of this client (and any subsequent reconnects on the same client).
  bool _supportsBatch = true;

  /// Set the first time we receive evidence (array reply OR any successful
  /// per-id reply during a batch frame) that the server is actually
  /// processing batches. Gates the auto-demotion above.
  bool _batchProven = false;

  final Map<int, Completer<dynamic>> _pendingById = {};

  /// Latest header notification handler (Electrum sends these as
  /// `blockchain.headers.subscribe` server pushes after the initial call).
  void Function(Map<String, dynamic>)? _onHeader;

  /// Push handler for `blockchain.scripthash.subscribe` notifications. The
  /// server fires this with `[scripthash, status]` whenever a subscribed
  /// scripthash's history fingerprint changes (incl. confirmation depth).
  void Function(String scripthash, String? status)? _onScripthashStatus;

  void setScripthashStatusHandler(void Function(String scripthash, String? status) handler) {
    _onScripthashStatus = handler;
  }

  void Function(bool connected)? onConnectionChanged;

  bool get isConnected => _connected;

  void _log(LogLevel level, String message) => log(level, message, coin: coinSymbol);

  // ----- Connection -----

  Future<void> connect({
    required String host,
    required int port,
    bool useSsl = false,
    String? socksHost,
    int? socksPort,
  }) async {
    await close();

    if (socksPort != null && socksPort > 0) {
      final socks = await SOCKSSocket.create(
        proxyHost: socksHost ?? InternetAddress.loopbackIPv4.address,
        proxyPort: socksPort,
        sslEnabled: useSsl,
      );
      await socks.connect();
      await socks.connectTo(host, port);
      _socksSocket = socks;
      _socketSub = socks.inputStream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } else {
      Socket socket = await Socket.connect(host, port, timeout: Duration(seconds: 10));
      if (useSsl) {
        socket = await SecureSocket.secure(socket, host: host);
      }
      _plainSocket = socket;
      _socketSub = socket.listen(_onData, onError: _onError, onDone: _onDone, cancelOnError: false);
    }

    _setConnected(true);
    _startKeepalive();
  }

  Future<void> close() async {
    _aliveTimer?.cancel();
    _aliveTimer = null;
    await _socketSub?.cancel();
    _socketSub = null;
    try {
      await _plainSocket?.close();
    } catch (_) {}
    _plainSocket = null;
    try {
      await _socksSocket?.close();
    } catch (_) {}
    _socksSocket = null;

    for (final c in _pendingById.values) {
      if (!c.isCompleted) {
        c.completeError(ElectrumDisconnectException());
      }
    }
    _pendingById.clear();
    _onHeader = null;
    _onScripthashStatus = null;
    _buffer = '';
    _setConnected(false);
  }

  void _startKeepalive() {
    _aliveTimer?.cancel();
    _aliveTimer = Timer.periodic(_aliveInterval, (_) async {
      try {
        await ping();
      } catch (e) {
        _log(LogLevel.warn, 'ping failed: $e');
        await close();
      }
    });
  }

  void _setConnected(bool value) {
    if (_connected == value) return;
    _connected = value;
    try {
      onConnectionChanged?.call(value);
    } catch (_) {}
  }

  // ----- Wire I/O -----

  void _send(String line) {
    if (_socksSocket != null) {
      _socksSocket!.write(line);
    } else if (_plainSocket != null) {
      _plainSocket!.add(utf8.encode(line));
    } else {
      throw ElectrumDisconnectException('Electrum: not connected');
    }
  }

  void _onData(List<int> chunk) {
    _buffer += utf8.decode(Uint8List.fromList(chunk), allowMalformed: true);
    while (true) {
      final nl = _buffer.indexOf('\n');
      if (nl < 0) break;
      final line = _buffer.substring(0, nl).trim();
      _buffer = _buffer.substring(nl + 1);
      if (line.isEmpty) continue;
      try {
        _dispatch(json.decode(line));
      } catch (e) {
        _log(LogLevel.warn, 'parse error: $e (line=$line)');
      }
    }
  }

  void _onError(Object error, [StackTrace? st]) {
    _log(LogLevel.error, 'socket error: $error');
    close();
  }

  void _onDone() {
    _log(
      LogLevel.info,
      'socket closed (pending=${_pendingById.length}, '
      'buffer=${_buffer.length} bytes)',
    );
    close();
  }

  void _dispatch(dynamic message) {
    // JSON-RPC 2.0 batch response. Receiving one is hard proof the server
    // speaks batch — lock in [_batchProven] so a later transient disconnect
    // can't trick us into demoting.
    if (message is List) {
      _batchProven = true;
      for (final entry in message) _dispatch(entry);
      return;
    }
    if (message is! Map<String, dynamic>) return;

    if (message.containsKey('id') && message['id'] != null) {
      final id = int.tryParse(message['id'].toString());
      if (id == null) return;
      final completer = _pendingById.remove(id);
      if (completer == null) return;
      if (message.containsKey('error') && message['error'] != null) {
        completer.completeError(_ElectrumError(message['error']));
      } else {
        completer.complete(message['result']);
      }
      return;
    }

    final method = message['method'];
    if (method == 'blockchain.headers.subscribe') {
      final params = message['params'];
      if (params is List && params.isNotEmpty) {
        final first = params.first;
        if (first is Map) _onHeader?.call(first.cast<String, dynamic>());
      }
      return;
    }
    if (method == 'blockchain.scripthash.subscribe') {
      final params = message['params'];
      if (params is List && params.length >= 2) {
        final sh = params[0];
        final status = params[1];
        if (sh is String) {
          _onScripthashStatus?.call(sh, status is String ? status : null);
        }
      }
      return;
    }
  }

  Future<dynamic> _call(String method, List<Object?> params, {Duration? timeout}) {
    if (!_connected) {
      return Future.error(ElectrumDisconnectException());
    }

    final id = _nextId++;
    final completer = Completer<dynamic>();
    _pendingById[id] = completer;
    final body = json.encode({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params});
    try {
      _send('$body\n');
    } catch (e) {
      _pendingById.remove(id);
      return Future.error(e);
    }
    return completer.future.timeout(
      timeout ?? _requestTimeout,
      onTimeout: () {
        _pendingById.remove(id);
        throw TimeoutException('Electrum call $method timed out');
      },
    );
  }

  /// Multi-request RPC. Sends [requests] in one JSON-RPC 2.0 array frame
  /// when [_supportsBatch] is true (auto-demoted on first all-disconnect
  /// failure against a server that never returned a batch reply); otherwise
  /// pipelines individual frames over the socket capped at [_pipelineChunk]
  /// in flight. Throws the first per-request error.
  Future<List<dynamic>> callBatch(List<BatchRpc> requests, {Duration? timeout}) async {
    final results = await callBatchTolerant(requests, timeout: timeout);
    for (final r in results) {
      if (r.error != null) throw r.error!;
    }
    return [for (final r in results) r.result];
  }

  /// Like [callBatch] but exposes per-request errors instead of throwing.
  Future<List<BatchRpcResult>> callBatchTolerant(
    List<BatchRpc> requests, {
    Duration? timeout,
  }) async {
    if (!_connected) {
      throw ElectrumDisconnectException();
    }
    if (requests.isEmpty) return const [];

    // Cap any single wire frame at [_pipelineChunk]. Big batches get split
    // into sequential sub-frames; many public Electrum servers (Blockstream
    // electrs, public ElectrumX nodes) cap response size / request count
    // per frame and silently drop the socket when exceeded.
    if (_supportsBatch) {
      final results = <BatchRpcResult>[];
      for (var start = 0; start < requests.length; start += _pipelineChunk) {
        final end = (start + _pipelineChunk).clamp(0, requests.length);
        results.addAll(await _callArrayBatch(requests.sublist(start, end), timeout: timeout));
        // Auto-demote inside _callArrayBatch may flip us mid-loop.
        if (!_supportsBatch) {
          final remaining = requests.sublist(end);
          if (remaining.isNotEmpty) {
            results.addAll(await _callPipelined(remaining, timeout: timeout));
          }
          break;
        }
      }
      return results;
    }
    return _callPipelined(requests, timeout: timeout);
  }

  /// Single JSON-RPC 2.0 array frame. The big win when the server supports
  /// it: one TCP round-trip instead of N (subject to server send buffer).
  Future<List<BatchRpcResult>> _callArrayBatch(List<BatchRpc> requests, {Duration? timeout}) async {
    final ids = <int>[];
    final completers = <Completer<dynamic>>[];
    for (var i = 0; i < requests.length; i++) {
      final id = _nextId++;
      final c = Completer<dynamic>();
      ids.add(id);
      completers.add(c);
      _pendingById[id] = c;
    }

    final body = json.encode([
      for (var i = 0; i < requests.length; i++)
        {
          'jsonrpc': '2.0',
          'id': ids[i],
          'method': requests[i].method,
          'params': requests[i].params,
        },
    ]);

    try {
      _send('$body\n');
    } catch (e) {
      for (final id in ids) {
        _pendingById.remove(id);
      }
      rethrow;
    }

    final deadline = timeout ?? _requestTimeout;
    final results = <BatchRpcResult>[];
    for (var i = 0; i < completers.length; i++) {
      try {
        final r = await completers[i].future.timeout(
          deadline,
          onTimeout: () {
            _pendingById.remove(ids[i]);
            throw TimeoutException('Electrum batch entry timed out');
          },
        );
        results.add(BatchRpcResult(result: r));
      } catch (e) {
        results.add(BatchRpcResult(error: e));
      }
    }

    // Any non-disconnect reply (success or RPC error) proves the server
    // accepted the array frame, even if it streams replies as separate
    // lines instead of a wrapping array.
    if (results.any((r) => r.error == null || !isElectrumDisconnectError(r.error!))) {
      _batchProven = true;
    }

    // Auto-demote: array frame failed wholesale and the server has never
    // proven batch support — assume it can't handle JSON-RPC arrays and
    // retry transparently as a pipelined batch on the next call.
    if (!_batchProven && results.every((r) => r.error != null)) {
      _supportsBatch = false;
      _log(
        LogLevel.warn,
        'server rejected JSON-RPC batch frame; falling back to pipelined requests',
      );
    }

    return results;
  }

  /// Pipelined fallback: many individual `{…}\n` frames in flight at once,
  /// capped at [_pipelineChunk] per round so we don't bury a slow server.
  Future<List<BatchRpcResult>> _callPipelined(List<BatchRpc> requests, {Duration? timeout}) async {
    final results = <BatchRpcResult>[];
    for (var start = 0; start < requests.length; start += _pipelineChunk) {
      final end = (start + _pipelineChunk).clamp(0, requests.length);
      final futures = [
        for (var i = start; i < end; i++)
          _call(requests[i].method, requests[i].params, timeout: timeout)
              .then<BatchRpcResult>((r) => BatchRpcResult(result: r))
              .catchError((Object e) => BatchRpcResult(error: e)),
      ];
      results.addAll(await Future.wait(futures));
    }
    return results;
  }

  // ----- Public RPC surface -----

  Future<List<String>> serverVersion({String client = 'skylight', String protocol = '1.4'}) async {
    final result = await _call('server.version', [client, protocol]);
    if (result is List) return result.map((e) => e.toString()).toList();
    return [];
  }

  Future<void> ping() async {
    await _call('server.ping', []);
  }

  Future<Map<String, int>> getBalance(String scripthash) async {
    final result = await _call('blockchain.scripthash.get_balance', [scripthash]);
    if (result is Map) {
      return {
        'confirmed': (result['confirmed'] as num?)?.toInt() ?? 0,
        'unconfirmed': (result['unconfirmed'] as num?)?.toInt() ?? 0,
      };
    }
    return {'confirmed': 0, 'unconfirmed': 0};
  }

  Future<List<Map<String, dynamic>>> getHistory(String scripthash) async {
    final result = await _call('blockchain.scripthash.get_history', [scripthash]);
    if (result is List) {
      return result.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    }
    return [];
  }

  /// Subscribes to state changes for [scripthash]. Returns the current status
  /// hash (a fingerprint of the scripthash's history), or `null` when the
  /// scripthash has no history. Subsequent state changes arrive via the
  /// handler registered with [setScripthashStatusHandler].
  Future<String?> subscribeScripthash(String scripthash) async {
    final result = await _call('blockchain.scripthash.subscribe', [scripthash]);
    return result is String ? result : null;
  }

  Future<List<Map<String, dynamic>>> listUnspent(String scripthash) async {
    final result = await _call('blockchain.scripthash.listunspent', [scripthash]);
    if (result is List) {
      return result.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    }
    return [];
  }

  Future<dynamic> getTransaction(String hash, {bool verbose = false}) async {
    return _call('blockchain.transaction.get', [hash, verbose]);
  }

  Future<String> broadcastTransaction(String rawHex) async {
    final result = await _call('blockchain.transaction.broadcast', [rawHex]);
    if (result is String) return result;
    throw _ElectrumError('Unexpected broadcast response: $result');
  }

  /// Returns BTC/kB. Convert to sat/vB by `result * 1e8 / 1000`. Returns
  /// `null` when the server cannot provide an estimate (some servers
  /// return -1).
  Future<double?> estimateFee(int blocks) async {
    final result = await _call('blockchain.estimatefee', [blocks]);
    if (result is num) {
      final v = result.toDouble();
      return v <= 0 ? null : v;
    }
    return null;
  }

  /// Current mempool fee histogram: `[[feerateSatVb, vsize], ...]` sorted by
  /// fee rate descending. Empty when the server has no mempool data.
  Future<List<List<num>>> getFeeHistogram() async {
    final result = await _call('mempool.get_fee_histogram', []);
    if (result is! List) return const [];
    final out = <List<num>>[];
    for (final entry in result) {
      if (entry is List && entry.length >= 2 && entry[0] is num && entry[1] is num) {
        out.add([entry[0] as num, entry[1] as num]);
      }
    }
    return out;
  }

  /// Subscribes to new block headers. [onHeader] receives every push from
  /// the server; the returned map is the initial response (with `height`
  /// and `hex`).
  Future<Map<String, dynamic>> subscribeHeaders(
    void Function(Map<String, dynamic>) onHeader,
  ) async {
    _onHeader = onHeader;
    final result = await _call('blockchain.headers.subscribe', []);
    if (result is Map) return result.cast<String, dynamic>();
    return {};
  }

  /// Returns the 80-byte block header at [height] as hex.
  Future<String> getBlockHeader(int height) async {
    final result = await _call('blockchain.block.header', [height]);
    if (result is String && result.isNotEmpty) return result;
    throw _ElectrumError('Unexpected block header response: $result');
  }
}

/// One leg of a batched JSON-RPC call. Named with the `BatchRpc` prefix so
/// it doesn't collide with `package:bitcoin_base`'s `ElectrumRequest`.
class BatchRpc {
  const BatchRpc(this.method, this.params);
  final String method;
  final List<Object?> params;
}

/// Per-entry outcome of [ElectrumClient.callBatchTolerant]. Exactly one of
/// [result] / [error] is set.
class BatchRpcResult {
  const BatchRpcResult({this.result, this.error});
  final dynamic result;
  final Object? error;
}

class ElectrumDisconnectException implements Exception {
  const ElectrumDisconnectException([this.message = 'Electrum connection closed']);

  final String message;

  @override
  String toString() => message;
}

class _ElectrumError implements Exception {
  final dynamic raw;
  _ElectrumError(this.raw);
  @override
  String toString() => 'ElectrumError: $raw';
}

/// True when an RPC failed because the socket was closed or is unavailable.
bool isElectrumDisconnectError(Object error) {
  if (error is ElectrumDisconnectException) return true;
  if (error is StateError) {
    final msg = error.toString().toLowerCase();
    return msg.contains('electrum') &&
        (msg.contains('connection closed') || msg.contains('not connected'));
  }
  return false;
}

/// Standalone one-shot probe used by the connection-setup form to
/// verify an Electrum endpoint without spinning up a full client.
///
/// Opens a fresh socket (TCP, TLS, or via SOCKS5), sends a
/// `server.version` JSON-RPC request, and waits for a matching reply.
/// Returns normally on success and throws on any failure.
Future<void> probeElectrumServer({
  required String host,
  required int port,
  required bool useSsl,
  String? socksHost,
  int? socksPort,
  Duration timeout = const Duration(seconds: 10),
}) async {
  Socket? plainSocket;
  SOCKSSocket? socksSocket;
  StreamSubscription<List<int>>? sub;
  final completer = Completer<void>();
  final buffer = StringBuffer();

  void cleanup() {
    sub?.cancel();
    try {
      plainSocket?.destroy();
    } catch (_) {}
    plainSocket = null;
    try {
      socksSocket?.close();
    } catch (_) {}
    socksSocket = null;
  }

  void onData(List<int> chunk) {
    buffer.write(utf8.decode(Uint8List.fromList(chunk), allowMalformed: true));
    while (true) {
      final s = buffer.toString();
      final nl = s.indexOf('\n');
      if (nl < 0) break;
      final line = s.substring(0, nl).trim();
      buffer.clear();
      buffer.write(s.substring(nl + 1));
      if (line.isEmpty) continue;
      try {
        final msg = json.decode(line);
        if (msg is Map &&
            msg['id']?.toString() == '0' &&
            (msg['error'] == null) &&
            msg['result'] != null) {
          if (!completer.isCompleted) completer.complete();
          return;
        }
        if (msg is Map && msg['error'] != null) {
          if (!completer.isCompleted) {
            completer.completeError(_ElectrumError(msg['error']));
          }
          return;
        }
      } catch (_) {
        // ignore non-JSON or partial frames
      }
    }
  }

  try {
    if (socksPort != null && socksPort > 0) {
      final socks = await SOCKSSocket.create(
        proxyHost: socksHost ?? InternetAddress.loopbackIPv4.address,
        proxyPort: socksPort,
        sslEnabled: useSsl,
      );
      await socks.connect();
      await socks.connectTo(host, port);
      socksSocket = socks;
      sub = socks.inputStream.listen(onData);
      socks.write(
        '${jsonEncode({
          'jsonrpc': '2.0',
          'method': 'server.version',
          'params': ['', '1.4'],
          'id': 0,
        })}\n',
      );
    } else {
      Socket s = await Socket.connect(host, port, timeout: timeout);
      if (useSsl) {
        s = await SecureSocket.secure(s, host: host);
      }
      plainSocket = s;
      sub = s.listen(onData);
      s.add(
        utf8.encode(
          '${jsonEncode({
            'jsonrpc': '2.0',
            'method': 'server.version',
            'params': ['', '1.4'],
            'id': 0,
          })}\n',
        ),
      );
    }

    await completer.future.timeout(timeout);
  } finally {
    cleanup();
  }
}
