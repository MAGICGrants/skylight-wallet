import 'dart:io';

import 'package:wallet_ui/wallet_ui.dart' show isDesktopLayout;

/// True when the app shows its desktop layout: on Linux/Windows/macOS, and for
/// the iOS build running on a Mac (see [isDesktopLayout]). Layout only.
bool get isDesktop => isDesktopLayout;

/// True when running natively on a desktop OS (Linux/Windows/macOS).
///
/// What follows the OS rather than the layout keys off this: the wallet
/// password typed at every launch, and announcing incoming transactions from
/// the foreground. The iOS build on a Mac is not one of these. It keeps iOS's
/// keystore-held password, App Lock and background sync.
final bool isDesktopOS = Platform.isLinux || Platform.isWindows || Platform.isMacOS;

/// True on the mobile platforms (Android/iOS), the iOS build on a Mac included.
final bool isMobile = Platform.isAndroid || Platform.isIOS;
