import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:screen_protector/screen_protector.dart';

/// Blocks screenshots/screen recording (Android FLAG_SECURE + iOS) and covers
/// the app with a blur when it is backgrounded (iOS resign active), while the
/// screen is mounted. Use on screens that display secrets (seed, keys).
mixin SecureScreenMixin<T extends StatefulWidget> on State<T> {
  // screen_protector only implements Android/iOS; no-op elsewhere (desktop).
  bool get _supported => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    if (!_supported) return;
    ScreenProtector.preventScreenshotOn();
    ScreenProtector.protectDataLeakageWithBlur();
  }

  @override
  void dispose() {
    if (_supported) {
      ScreenProtector.preventScreenshotOff();
      ScreenProtector.protectDataLeakageWithBlurOff();
    }
    super.dispose();
  }
}
