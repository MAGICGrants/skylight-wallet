import 'dart:io';

import 'package:wallet_ui/wallet_ui.dart' show isDesktopLayout;
import 'package:wallet_infra/wallet_infra.dart' show WalletSecrets;

/// True when the app shows its desktop layout: on Linux/Windows/macOS, and for
/// the iOS build running on a Mac (see [isDesktopLayout]). Layout only.
bool get isDesktop => isDesktopLayout;

/// True when running natively on a desktop OS (Linux/Windows/macOS).
///
/// What follows the OS rather than the layout keys off this: announcing
/// incoming transactions from the foreground (no background isolate), and
/// "Lock after" a time without use. The iOS build on a Mac is not one of these.
/// It keeps iOS's App Lock and background sync.
final bool isDesktopOS = Platform.isLinux || Platform.isWindows || Platform.isMacOS;

/// True where the user types the wallet password at every launch: Linux and
/// Windows. Elsewhere it is generated at onboarding and kept in the keystore.
/// Read from wallet_infra's [WalletSecrets.holdsWalletPassword], the one
/// platform switch, so the app and wallet-core cannot disagree.
bool get typesWalletPassword => !WalletSecrets.holdsWalletPassword;

/// True where App Lock (the device's own prompt: biometrics or the device
/// passcode, Touch ID or the Mac's password on macOS) guards that generated
/// password: Android, iOS and macOS.
bool get usesDeviceLock => WalletSecrets.holdsWalletPassword;

/// True on the mobile platforms (Android/iOS), the iOS build on a Mac included.
final bool isMobile = Platform.isAndroid || Platform.isIOS;
