import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/socks_socket.dart';

/// Manages a pool of SOCKS connections for reuse.
///
/// Connections are keyed by destination (host:port) and proxy info.
/// This improves performance by avoiding the overhead of establishing
/// new SOCKS5 connections for each request.
class SocksConnectionPool {
  static final SocksConnectionPool instance = SocksConnectionPool._();
  SocksConnectionPool._();

  final Map<String, _PooledConnection> _connections = {};

  /// Maximum idle time before a connection is considered stale
  static const Duration maxIdleTime = Duration(seconds: 30);

  String _makeKey(String host, int port, String proxyHost, int proxyPort, bool ssl) {
    return '$proxyHost:$proxyPort->$host:$port:${ssl ? 'ssl' : 'plain'}';
  }

  /// Get or create a connection for the given destination.
  Future<SOCKSSocket> getConnection({
    required String host,
    required int port,
    required String proxyHost,
    required int proxyPort,
    required bool sslEnabled,
  }) async {
    final key = _makeKey(host, port, proxyHost, proxyPort, sslEnabled);

    // Check if we have a valid existing connection
    final existing = _connections[key];
    if (existing != null && !existing.isStale) {
      existing.lastUsed = DateTime.now();
      return existing.socket;
    }

    // Close stale connection if exists
    if (existing != null) {
      log(LogLevel.info, 'Closing stale SOCKS connection to $host:$port');
      await _closeConnection(key);
    }

    // Create new connection
    log(LogLevel.info, 'Creating new SOCKS connection to $host:$port');
    final socket = await SOCKSSocket.create(
      proxyHost: proxyHost,
      proxyPort: proxyPort,
      sslEnabled: sslEnabled,
    );

    await socket.connect();
    await socket.connectTo(host, port);

    _connections[key] = _PooledConnection(socket: socket);
    return socket;
  }

  /// Remove a connection from the pool (e.g., on error).
  Future<void> removeConnection({
    required String host,
    required int port,
    required String proxyHost,
    required int proxyPort,
    required bool sslEnabled,
  }) async {
    final key = _makeKey(host, port, proxyHost, proxyPort, sslEnabled);
    await _closeConnection(key);
  }

  Future<void> _closeConnection(String key) async {
    final conn = _connections.remove(key);
    if (conn != null) {
      try {
        await conn.socket.close();
      } catch (_) {}
    }
  }

  /// Close all connections in the pool.
  Future<void> closeAll() async {
    for (final key in _connections.keys.toList()) {
      await _closeConnection(key);
    }
  }

  /// Clean up stale connections.
  Future<void> cleanup() async {
    final staleKeys = _connections.entries.where((e) => e.value.isStale).map((e) => e.key).toList();

    for (final key in staleKeys) {
      log(LogLevel.info, 'Cleaning up stale connection: $key');
      await _closeConnection(key);
    }
  }
}

class _PooledConnection {
  final SOCKSSocket socket;
  DateTime lastUsed;

  _PooledConnection({required this.socket}) : lastUsed = DateTime.now();

  bool get isStale => DateTime.now().difference(lastUsed) > SocksConnectionPool.maxIdleTime;
}

class ParsedHttpResponse {
  final String httpVersion;
  final int statusCode;
  final String reasonPhrase;
  final Map<String, String> headers;
  final String body;
  final dynamic jsonBody; // Holds the decoded JSON if applicable

  ParsedHttpResponse({
    required this.httpVersion,
    required this.statusCode,
    required this.reasonPhrase,
    required this.headers,
    required this.body,
    this.jsonBody,
  });

  @override
  String toString() {
    return '''
--- PARSED RESPONSE ---
HTTP Version: $httpVersion
Status Code: $statusCode
Reason Phrase: $reasonPhrase
Headers: $headers
Body: $body
Decoded JSON: $jsonBody
-----------------------''';
  }
}

String getRawHttpRequestString(
  String method,
  String url, {
  Object? jsonBody,
  bool keepAlive = true,
}) {
  final uri = Uri.parse(url);
  final host = uri.host;

  final path = uri.path.isEmpty ? '/' : uri.path;
  final query = uri.hasQuery ? '?${uri.query}' : '';
  final fullPath = '$path$query';

  final request = StringBuffer();

  request.write('${method.toUpperCase()} $fullPath HTTP/1.1\r\n');
  request.write('Host: $host\r\n');
  request.write('Connection: ${keepAlive ? 'keep-alive' : 'close'}\r\n');
  request.write('Accept: */*\r\n');

  final jsonBodyStr = jsonBody is Object ? jsonBody.toString() : null;

  if (jsonBodyStr != null && jsonBodyStr.isNotEmpty) {
    final bodyBytes = utf8.encode(jsonBodyStr);
    request.write('Content-Type: application/json; charset=UTF-8\r\n');
    request.write('Content-Length: ${bodyBytes.length}\r\n');
  }

  request.write('\r\n');

  if (jsonBodyStr != null && jsonBodyStr.isNotEmpty) {
    request.write(jsonBodyStr);
  }

  return request.toString();
}

ParsedHttpResponse parseHttpResponse(String rawResponse) {
  final separator = '\r\n\r\n';
  final separatorIndex = rawResponse.indexOf(separator);

  if (separatorIndex == -1) {
    throw FormatException('Invalid HTTP response: No header/body separator found.');
  }

  final headersPart = rawResponse.substring(0, separatorIndex);
  final body = rawResponse.substring(separatorIndex + separator.length);
  final headerLines = headersPart.split('\r\n');

  final statusLine = headerLines.first;
  final statusLineParts = statusLine.split(' ');
  final httpVersion = statusLineParts[0];
  final statusCode = int.parse(statusLineParts[1]);
  final reasonPhrase = statusLineParts.sublist(2).join(' ');

  final headers = <String, String>{};
  for (var i = 1; i < headerLines.length; i++) {
    final line = headerLines[i];
    final colonIndex = line.indexOf(':');
    if (colonIndex != -1) {
      final key = line.substring(0, colonIndex).trim().toLowerCase();
      final value = line.substring(colonIndex + 1).trim();
      headers[key] = value;
    }
  }

  dynamic jsonBody;
  if (headers['content-type']?.contains('application/json') ?? false) {
    try {
      jsonBody = jsonDecode(body);
    } catch (e) {
      jsonBody = null;
    }
  }

  return ParsedHttpResponse(
    httpVersion: httpVersion,
    statusCode: statusCode,
    reasonPhrase: reasonPhrase,
    headers: headers,
    body: body,
    jsonBody: jsonBody,
  );
}

Future<ParsedHttpResponse> makeSocksHttpRequest(
  String method,
  String url,
  ({InternetAddress host, int port}) proxyInfo, {
  Object? body,
  bool? usePool,
}) async {
  final uri = Uri.parse(url);
  final pool = SocksConnectionPool.instance;
  final host = uri.host;
  final port = uri.port;
  final proxyHost = proxyInfo.host.address;
  final proxyPort = proxyInfo.port;
  final sslEnabled = uri.scheme == 'https';

  // Only use connection pooling on iOS by default (helps with iOS networking limitations)
  final shouldUsePool = usePool ?? Platform.isIOS;

  SOCKSSocket? socket;
  bool fromPool = false;

  try {
    if (shouldUsePool) {
      socket = await pool.getConnection(
        host: host,
        port: port,
        proxyHost: proxyHost,
        proxyPort: proxyPort,
        sslEnabled: sslEnabled,
      );
      fromPool = true;
    } else {
      socket = await SOCKSSocket.create(
        proxyHost: proxyHost,
        proxyPort: proxyPort,
        sslEnabled: sslEnabled,
      );
      await socket.connect();
      await socket.connectTo(host, port);
    }

    final rawRequest = getRawHttpRequestString(
      method,
      url,
      jsonBody: body,
      keepAlive: shouldUsePool,
    );
    final rawResponse = await socket.sendHttpRequest(rawRequest);
    final parsedResponse = parseHttpResponse(rawResponse);

    return parsedResponse;
  } catch (e) {
    log(LogLevel.error, 'makeSocksHttpRequest error: $e');
    // Remove the connection from pool on error
    if (fromPool) {
      await pool.removeConnection(
        host: host,
        port: port,
        proxyHost: proxyHost,
        proxyPort: proxyPort,
        sslEnabled: sslEnabled,
      );
    }
    rethrow;
  } finally {
    // Only close if not using pool
    if (!shouldUsePool && socket != null) {
      try {
        await socket.close();
      } catch (e) {
        log(LogLevel.error, 'Error closing socket: $e');
      }
    }
  }
}
