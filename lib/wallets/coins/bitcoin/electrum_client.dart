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

  Socket? _plainSocket;
  SOCKSSocket? _socksSocket;
  StreamSubscription<List<int>>? _socketSub;
  Timer? _aliveTimer;

  int _nextId = 0;
  String _buffer = '';
  bool _connected = false;

  final Map<int, Completer<dynamic>> _pendingById = {};

  /// Latest header notification handler (Electrum sends these as
  /// `blockchain.headers.subscribe` server pushes after the initial call).
  void Function(Map<String, dynamic>)? _onHeader;

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
    _log(LogLevel.info, 'socket closed');
    close();
  }

  void _dispatch(dynamic message) {
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

  /// Some Electrum servers reject `verbose: true` ("verbose transactions are
  /// currently unsupported"). Try verbose first, then fall back to raw hex.
  Future<dynamic> getTransactionBestEffort(String hash) async {
    try {
      return await getTransaction(hash, verbose: true);
    } catch (e) {
      if (isElectrumDisconnectError(e)) rethrow;
      final msg = e.toString().toLowerCase();
      if (msg.contains('verbose') || msg.contains('not supported') || msg.contains('unsupported')) {
        return await getTransaction(hash, verbose: false);
      }
      rethrow;
    }
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
