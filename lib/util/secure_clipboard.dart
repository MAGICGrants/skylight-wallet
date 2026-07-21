import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:spice_wallet/util/logging.dart';

/// Clipboard helper for secrets (seed, view key).
///
/// - Android: flags the clip as sensitive (`EXTRA_IS_SENSITIVE`, excluded from
///   previews/sync) and clears it after [clearAfter] via an in-app timer
///   (Android has no per-clip expiry API).
/// - iOS: writes with `localOnly` (no Handoff/Universal Clipboard) and an
///   `expirationDate`, so the OS clears it even if the app is gone.
class SecureClipboard {
  static const _channel = MethodChannel('org.magicgrants.spice/secure_clipboard');

  static Future<void> copy(String text, {Duration clearAfter = const Duration(seconds: 60)}) async {
    var nativeHandled = false;
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await _channel.invokeMethod('copySensitive', {
          'text': text,
          'clearAfterSeconds': clearAfter.inSeconds,
        });
        nativeHandled = true;
      } catch (e) {
        log(LogLevel.warn, 'secure clipboard channel failed: $e');
      }
    }
    if (!nativeHandled) {
      await Clipboard.setData(ClipboardData(text: text));
    }

    // iOS clears via the native expiration date; elsewhere run an in-app timer.
    if (!Platform.isIOS) {
      Future.delayed(clearAfter, () async {
        final current = await Clipboard.getData(Clipboard.kTextPlain);
        if (current?.text == text) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      });
    }
  }
}
