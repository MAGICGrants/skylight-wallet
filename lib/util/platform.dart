import 'dart:io';

/// True on the desktop platforms (Linux/Windows/macOS).
final bool isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;

/// True on the mobile platforms (Android/iOS).
final bool isMobile = Platform.isAndroid || Platform.isIOS;
