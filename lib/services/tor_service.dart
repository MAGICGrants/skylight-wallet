import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monero_light_wallet/util/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tor_ffi_plugin/tor_ffi_plugin.dart';

final pTorService = Provider((_) => TorService.sharedInstance);

enum TorConnectionStatus { disconnected, connecting, connected }

class TorService {
  Tor? _tor;
  String? _torDataDirPath;

  /// Current status. Same as that fired on the event bus.
  TorConnectionStatus get status => _status;
  TorConnectionStatus _status = TorConnectionStatus.disconnected;

  /// Singleton instance of the TorService.
  ///
  /// Use this to access the TorService and its properties.
  static final sharedInstance = TorService._();

  // private constructor for singleton
  TorService._();

  /// Getter for the proxyInfo.
  ///
  /// Throws if Tor is not connected.
  ({InternetAddress host, int port}) getProxyInfo() {
    if (status == TorConnectionStatus.connected) {
      return (host: InternetAddress.loopbackIPv4, port: _tor!.port);
    } else {
      throw Exception("Tor proxy info fetched while not connected!");
    }
  }

  /// Start the Tor service.
  ///
  /// This will start the Tor service and establish a Tor circuit.
  ///
  /// Throws an exception if the Tor library was not inited or if the Tor
  /// service fails to start.
  ///
  /// Returns a Future that completes when the Tor service has started.
  Future<void> start() async {
    _tor ??= Tor.instance;
    _torDataDirPath ??= (await getApplicationDocumentsDirectory()).path;

    // Start the Tor service.
    try {
      _status = TorConnectionStatus.connecting;
      await _tor!.start(torDataDirPath: _torDataDirPath!);
      _status = TorConnectionStatus.connected;
      return;
    } catch (e, s) {
      log(LogLevel.error, 'TorService.start failed');
      log(LogLevel.error, s.toString());
      log(LogLevel.error, s.toString());

      _status = TorConnectionStatus.disconnected;

      rethrow;
    }
  }

  Future<void> disable() async {
    if (_status == TorConnectionStatus.disconnected) {
      return;
    }

    _tor!.disable();
    await _tor?.stop();
    _status = TorConnectionStatus.disconnected;

    return;
  }

  Future<void> waitUntilConnected() async {
    final completer = Completer<void>();

    Timer.periodic(Duration(milliseconds: 50), (timer) {
      if (status == TorConnectionStatus.connected) {
        timer.cancel();
        completer.complete();
      }
    });

    return completer.future;
  }
}
