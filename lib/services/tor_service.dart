import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skylight_wallet/util/dirs.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:tor_ffi_plugin/tor_ffi_plugin.dart';

final pTorService = Provider((_) => TorService.sharedInstance);

enum TorConnectionStatus { disconnected, connecting, connected }

class TorService {
  Tor? _tor;
  String? _torDataDirPath;
  Future<void>? _startInFlight;

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
    if (_status == TorConnectionStatus.connected) return;

    // Concurrent callers join the attempt already running rather than starting
    // a second Tor.
    final inFlight = _startInFlight;
    if (inFlight != null) return inFlight;

    final attempt = _start();
    _startInFlight = attempt;

    try {
      await attempt;
    } finally {
      if (identical(_startInFlight, attempt)) _startInFlight = null;
    }
  }

  Future<void> _start() async {
    _tor ??= Tor.instance;
    _torDataDirPath ??= (await getAppDir()).path;

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

  /// Waits for Tor to come up, returning whether it did.
  ///
  /// Bounded, and it always cancels its poll timer. The previous version did
  /// neither: a Tor that never connected left a 50ms timer polling for the life
  /// of the isolate — one per call — and the future never completed at all, so
  /// a caller without its own timeout waited forever.
  ///
  /// A start attempt that failed earlier is retried here, since nothing else
  /// retries it and the app would otherwise stay wedged until a restart.
  Future<bool> waitUntilConnected({Duration timeout = const Duration(seconds: 60)}) async {
    if (status == TorConnectionStatus.connected) return true;

    if (_status == TorConnectionStatus.disconnected && _startInFlight == null) {
      log(LogLevel.info, 'Tor is not running; retrying start.');
      unawaited(start().catchError((Object e) => log(LogLevel.warn, 'Tor start retry failed: $e')));
    }

    final completer = Completer<bool>();
    Timer? poll;
    Timer? deadline;

    void finish(bool connected) {
      poll?.cancel();
      deadline?.cancel();
      if (!completer.isCompleted) completer.complete(connected);
    }

    poll = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (status == TorConnectionStatus.connected) finish(true);
    });

    deadline = Timer(timeout, () {
      log(LogLevel.warn, 'Gave up waiting for Tor after ${timeout.inSeconds}s.');
      finish(false);
    });

    return completer.future;
  }
}
