import 'package:flutter/widgets.dart';
import 'package:screen_protector/screen_protector.dart';

/// Blocks screenshots/screen recording (Android FLAG_SECURE + iOS) and covers
/// the app with a blur when it is backgrounded (iOS resign active), while the
/// screen is mounted. Use on screens that display secrets (seed, keys).
mixin SecureScreenMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    ScreenProtector.preventScreenshotOn();
    ScreenProtector.protectDataLeakageWithBlur();
  }

  @override
  void dispose() {
    ScreenProtector.preventScreenshotOff();
    ScreenProtector.protectDataLeakageWithBlurOff();
    super.dispose();
  }
}
