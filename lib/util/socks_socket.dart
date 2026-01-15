import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:skylight_wallet/util/logging.dart';

/// A SOCKS5 socket.
///
/// A Dart 3 Socket wrapper that implements the SOCKS5 protocol.  Now with SSL!
///
/// Properties:
///  - [proxyHost]: The host of the SOCKS5 proxy server.
///  - [proxyPort]: The port of the SOCKS5 proxy server.
///  - [_socksSocket]: The underlying Socket that connects to the SOCKS5 proxy
///  server.
///  - [_responseController]: A StreamController that listens to the
///  [_socksSocket] and broadcasts the response.
///
/// Methods:
/// - connect: Connects to the SOCKS5 proxy server.
/// - connectTo: Connects to the specified [domain] and [port] through the
/// SOCKS5 proxy server.
/// - write: Converts [object] to a String by invoking [Object.toString] and
/// sends the encoding of the result to the socket.
/// - sendServerFeaturesCommand: Sends the server.features command to the
/// proxy server.
/// - close: Closes the connection to the Tor proxy.
///
/// Usage:
/// ```dart
/// // Instantiate a socks socket at localhost and on the port selected by the
/// // tor service.
/// var socksSocket = await SOCKSSocket.create(
///  proxyHost: InternetAddress.loopbackIPv4.address,
///  proxyPort: tor.port,
///  // sslEnabled: true, // For SSL connections.
///  );
///
/// // Connect to the socks instantiated above.
/// await socksSocket.connect();
///
/// // Connect to bitcoincash.stackwallet.com on port 50001 via socks socket.
/// await socksSocket.connectTo(
/// 'bitcoincash.stackwallet.com', 50001);
///
/// // Send a server features command to the connected socket, see method for
/// // more specific usage example..
/// await socksSocket.sendServerFeaturesCommand();
/// await socksSocket.close();
/// ```
///
/// See also:
/// - SOCKS5 protocol(https://www.ietf.org/rfc/rfc1928.txt)
class SOCKSSocket {
  /// The host of the SOCKS5 proxy server.
  final String proxyHost;

  /// The port of the SOCKS5 proxy server.
  final int proxyPort;

  /// The underlying Socket that connects to the SOCKS5 proxy server.
  late final Socket _socksSocket;

  /// Getter for the underlying Socket that connects to the SOCKS5 proxy server.
  Socket get socket => sslEnabled ? _secureSocksSocket : _socksSocket;

  /// A wrapper around the _socksSocket that enables SSL connections.
  late final Socket _secureSocksSocket;

  /// A StreamController that listens to the _socksSocket and broadcasts.
  late final StreamController<List<int>> _responseController;

  /// A StreamController that listens to the _secureSocksSocket and broadcasts.
  late final StreamController<List<int>> _secureResponseController;

  /// Getter for the StreamController that listens to the _socksSocket and
  /// broadcasts, or the _secureSocksSocket and broadcasts if SSL is enabled.
  StreamController<List<int>> get responseController =>
      sslEnabled ? _secureResponseController : _responseController;

  /// A StreamSubscription that listens to the _socksSocket or the
  /// _secureSocksSocket if SSL is enabled.
  StreamSubscription<List<int>>? _subscription;

  /// Getter for the StreamSubscription that listens to the _socksSocket or the
  /// _secureSocksSocket if SSL is enabled.
  StreamSubscription<List<int>>? get subscription => _subscription;

  /// Is SSL enabled?
  final bool sslEnabled;

  /// Private constructor.
  SOCKSSocket._(this.proxyHost, this.proxyPort, this.sslEnabled) {
    // Initialize stream controllers with error handling to prevent uncaught errors
    _responseController = StreamController.broadcast(onListen: null, onCancel: null);
    _secureResponseController = StreamController.broadcast(onListen: null, onCancel: null);
  }

  /// Provides a stream of data as List<int>.
  Stream<List<int>> get inputStream =>
      sslEnabled ? _secureResponseController.stream : _responseController.stream;

  /// Provides a StreamSink compatible with List<int> for sending data.
  StreamSink<List<int>> get outputStream {
    // Create a simple StreamSink wrapper for _socksSocket and
    // _secureSocksSocket that accepts List<int> and forwards it to write method.
    var sink = StreamController<List<int>>();
    sink.stream.listen((data) {
      if (sslEnabled) {
        _secureSocksSocket.add(data);
      } else {
        _socksSocket.add(data);
      }
    });
    return sink.sink;
  }

  /// Creates a SOCKS5 socket to the specified [proxyHost] and [proxyPort].
  ///
  /// This method is a factory constructor that returns a Future that resolves
  /// to a SOCKSSocket instance.
  ///
  /// Parameters:
  /// - [proxyHost]: The host of the SOCKS5 proxy server.
  /// - [proxyPort]: The port of the SOCKS5 proxy server.
  ///
  /// Returns:
  ///  A Future that resolves to a SOCKSSocket instance.
  static Future<SOCKSSocket> create({
    required String proxyHost,
    required int proxyPort,
    bool sslEnabled = false,
  }) async {
    // Create a SOCKS socket instance.
    var instance = SOCKSSocket._(proxyHost, proxyPort, sslEnabled);

    // Initialize the SOCKS socket.
    await instance._init();

    // Return the SOCKS socket instance.
    return instance;
  }

  /// Constructor.
  SOCKSSocket({required this.proxyHost, required this.proxyPort, required this.sslEnabled}) {
    // Initialize stream controllers
    _responseController = StreamController.broadcast();
    _secureResponseController = StreamController.broadcast();
    _init();
  }

  /// Initializes the SOCKS socket.
  ///
  /// This method is a private method that is called by the constructor.
  ///
  /// Returns:
  ///   A Future that resolves to void.
  Future<void> _init() async {
    // Connect to the SOCKS proxy server.
    _socksSocket = await Socket.connect(proxyHost, proxyPort);

    // Listen to the socket.
    _subscription = _socksSocket.listen(
      (data) {
        // Add the data to the response controller.
        if (!_responseController.isClosed) {
          _responseController.add(data);
        }
      },
      onError: (e, stackTrace) {
        // Log the error for debugging
        log(LogLevel.error, 'SOCKSSocket error: $e');
        // Only forward error if controller is open and has listeners
        if (!_responseController.isClosed && _responseController.hasListener) {
          _responseController.addError(e, stackTrace);
        }
      },
      onDone: () {
        // Socket closed - don't close controller here as it may be reused
        log(LogLevel.info, 'SOCKSSocket: connection closed');
      },
    );
  }

  /// Connects to the SOCKS socket.
  ///
  /// Returns:
  ///  A Future that resolves to void.
  Future<void> connect() async {
    // Greeting and method selection.
    _socksSocket.add([0x05, 0x01, 0x00]);

    // Wait for server response.
    var response = await _responseController.stream.first;

    // Check if the connection was successful.
    if (response[1] != 0x00) {
      throw Exception('socks_socket.connect(): Failed to connect to SOCKS5 proxy.');
    }

    return;
  }

  /// SOCKS5 reply codes for better error messages.
  static const Map<int, String> _socks5ReplyCodes = {
    0x00: 'Succeeded',
    0x01: 'General SOCKS server failure',
    0x02: 'Connection not allowed by ruleset',
    0x03: 'Network unreachable',
    0x04: 'Host unreachable',
    0x05: 'Connection refused',
    0x06: 'TTL expired',
    0x07: 'Command not supported',
    0x08: 'Address type not supported',
  };

  /// Connects to the specified [domain] and [port] through the SOCKS socket.
  ///
  /// Parameters:
  /// - [domain]: The domain to connect to.
  /// - [port]: The port to connect to.
  ///
  /// Returns:
  ///   A Future that resolves to void.
  Future<void> connectTo(String domain, int port) async {
    // Connect command.
    var request = [
      0x05, // SOCKS version.
      0x01, // Connect command.
      0x00, // Reserved.
      0x03, // Domain name.
      domain.length,
      ...domain.codeUnits,
      (port >> 8) & 0xFF,
      port & 0xFF,
    ];

    // Send the connect command to the SOCKS proxy server.
    _socksSocket.add(request);

    // Wait for server response.
    var response = await _responseController.stream.first;

    // Check if the connection was successful.
    if (response[1] != 0x00) {
      final replyCode = response[1];
      final replyMessage = _socks5ReplyCodes[replyCode] ?? 'Unknown error';
      throw Exception(
        'socks_socket.connectTo(): Failed to connect to $domain:$port - SOCKS5 error $replyCode: $replyMessage',
      );
    }

    // Upgrade to SSL if needed.
    if (sslEnabled) {
      // Upgrade to SSL.
      _secureSocksSocket = await SecureSocket.secure(
        _socksSocket,
        host: domain,
        // onBadCertificate: (_) => true, // Uncomment this to bypass certificate validation (NOT recommended for production).
      );

      // Listen to the secure socket.
      _subscription = _secureSocksSocket.listen(
        (data) {
          // Add the data to the response controller.
          if (!_secureResponseController.isClosed) {
            _secureResponseController.add(data);
          }
        },
        onError: (e, stackTrace) {
          // Log the error for debugging
          log(LogLevel.error, 'SOCKSSocket (secure) error: $e');
          // Only forward error if controller is open and has listeners
          if (!_secureResponseController.isClosed && _secureResponseController.hasListener) {
            _secureResponseController.addError(e, stackTrace);
          }
        },
        onDone: () {
          // Close the response controller when the socket is closed.
          if (!_secureResponseController.isClosed) {
            _secureResponseController.close();
          }
        },
      );
    }

    return;
  }

  /// Converts [object] to a String by invoking [Object.toString] and
  /// sends the encoding of the result to the socket.
  ///
  /// Parameters:
  /// - [object]: The object to write to the socket.
  ///
  /// Returns:
  ///  A Future that resolves to void.
  void write(Object? object) {
    // Don't write null.
    if (object == null) return;

    // Write the data to the socket.
    List<int> data = utf8.encode(object.toString());
    if (sslEnabled) {
      _secureSocksSocket.add(data);
    } else {
      _socksSocket.add(data);
    }
  }

  /// Closes the connection to the Tor proxy.
  ///
  /// Returns:
  ///  A Future that resolves to void.
  Future<void> close() async {
    // Ensure all data is sent before closing.
    try {
      if (sslEnabled) {
        await _secureSocksSocket.flush();
      }
      await _socksSocket.flush();
    } finally {
      await _subscription?.cancel();
      await _socksSocket.close();
      if (!_responseController.isClosed) {
        _responseController.close();
      }
      if (sslEnabled && !_secureResponseController.isClosed) {
        _secureResponseController.close();
      }
    }
  }

  StreamSubscription<List<int>> listen(
    void Function(List<int> data)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return sslEnabled
        ? _secureResponseController.stream.listen(
            onData,
            onError: onError,
            onDone: onDone,
            cancelOnError: cancelOnError,
          )
        : _responseController.stream.listen(
            onData,
            onError: onError,
            onDone: onDone,
            cancelOnError: cancelOnError,
          );
  }

  /// Sends the server.features command to the proxy server.
  ///
  /// This demos how to send the server.features command.  Use as an example
  /// for sending other commands.
  ///
  /// Returns:
  ///   A Future that resolves to void.
  Future<void> sendServerFeaturesCommand() async {
    // The server.features command.
    const String command = '{"jsonrpc":"2.0","id":"0","method":"server.features","params":[]}';

    if (!sslEnabled) {
      // Send the command to the proxy server.
      _socksSocket.writeln(command);

      // Wait for the response from the proxy server.
      var responseData = await _responseController.stream.first;
      if (kDebugMode) {
        log(LogLevel.info, "responseData: ${utf8.decode(responseData)}");
      }
    } else {
      // Send the command to the proxy server.
      _secureSocksSocket.writeln(command);

      // Wait for the response from the proxy server.
      var responseData = await _secureResponseController.stream.first;
      if (kDebugMode) {
        log(LogLevel.info, "secure responseData: ${utf8.decode(responseData)}");
      }
    }

    return;
  }

  Future<String> send(String rawRequest) async {
    write(rawRequest);
    final buffer = StringBuffer();
    await for (final response in inputStream) {
      buffer.write(utf8.decode(response));
      if (buffer.toString().contains("\r\n\r\n")) {
        break;
      }
    }
    return buffer.toString();
  }

  /// Send an HTTP request and read the full response including body.
  ///
  /// This method properly handles Content-Length to read the complete response,
  /// which is necessary for keep-alive connections.
  Future<String> sendHttpRequest(String rawRequest) async {
    write(rawRequest);

    final bytes = <int>[];
    String? headers;
    int? contentLength;
    int headerEndIndex = -1;

    await for (final chunk in inputStream) {
      bytes.addAll(chunk);

      // Try to find the end of headers if we haven't yet
      if (headers == null) {
        final current = utf8.decode(bytes, allowMalformed: true);
        headerEndIndex = current.indexOf('\r\n\r\n');

        if (headerEndIndex != -1) {
          headers = current.substring(0, headerEndIndex);

          // Parse Content-Length from headers
          final contentLengthMatch = RegExp(
            r'content-length:\s*(\d+)',
            caseSensitive: false,
          ).firstMatch(headers);
          if (contentLengthMatch != null) {
            contentLength = int.parse(contentLengthMatch.group(1)!);
          }

          // Check if connection will close (no keep-alive possible)
          final connectionClose = headers.toLowerCase().contains('connection: close');
          if (connectionClose) {
            // Server will close connection, read until EOF
            contentLength = null;
          }
        }
      }

      // Check if we have the full response
      if (headers != null) {
        final headerBytes = utf8.encode('$headers\r\n\r\n').length;
        final bodyBytesReceived = bytes.length - headerBytes;

        if (contentLength != null && bodyBytesReceived >= contentLength) {
          // We have the full response based on Content-Length
          break;
        } else if (contentLength == null) {
          // No Content-Length, check for end of chunked encoding or connection close
          final current = utf8.decode(bytes, allowMalformed: true);
          if (current.contains('\r\n0\r\n\r\n')) {
            // End of chunked encoding
            break;
          }
          // For connection: close, we'll read until the stream ends
        }
      }
    }

    return utf8.decode(bytes);
  }
}
