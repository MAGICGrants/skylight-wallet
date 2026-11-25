import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'package:skylight_wallet/util/logging.dart';

/// A QR that can grow to fill the screen, as on Receive and on a used
/// address's own screen. Brightness is held at full for exactly as long as
/// [qrEnlarged] is true, and otherwise left to the system: the screen itself
/// never takes it over.
mixin QrBrightness<T extends StatefulWidget> on State<T> {
  /// Whether the QR is grown to fill the screen.
  var qrEnlarged = false;

  /// Brightness is only managed on phones, so only they offer the enlarge
  /// hint, which promises a brighter screen.
  static bool get canBrighten => Platform.isAndroid || Platform.isIOS;

  @override
  void dispose() {
    // Left with the QR still enlarged: hand brightness back on the way out.
    if (qrEnlarged) _releaseBrightness();
    super.dispose();
  }

  void toggleQr() {
    setState(() => qrEnlarged = !qrEnlarged);
    // No await before either call reaches the plugin, and both go down one
    // method channel, so the platform sees them in tap order: a quick
    // enlarge-shrink cannot land the raise after the release.
    qrEnlarged ? _maximizeBrightness() : _releaseBrightness();
  }

  /// Turns the screen up while the QR is enlarged, so it still scans in
  /// daylight.
  Future<void> _maximizeBrightness() async {
    try {
      await ScreenBrightness().setApplicationScreenBrightness(1.0);
    } catch (error) {
      log(LogLevel.warn, 'Could not raise screen brightness for the QR code: $error');
    }
  }

  /// Hands brightness back to the system.
  ///
  /// This resets the override rather than setting it back to whatever the
  /// system brightness read before. An application override is an absolute
  /// value pinned on the window, and while one is set Android ignores the
  /// system brightness entirely: writing the old value back left the screen
  /// deaf to auto-brightness and to the user's own slider until the app was
  /// restarted (skylight-wallet#169). Resetting drops the override, so the
  /// window follows the system setting again -- which is both the brightness
  /// the user had before and the one they can keep changing.
  Future<void> _releaseBrightness() async {
    try {
      await ScreenBrightness().resetApplicationScreenBrightness();
    } catch (error) {
      log(LogLevel.warn, 'Could not hand screen brightness back to the system: $error');
    }
  }
}
