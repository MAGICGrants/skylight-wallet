// SecureClipboard lives in wallet-core (`wallet_infra`) with a fixed, app-neutral
// MethodChannel name (`org.magicgrants.wallet/secure_clipboard`, per D10). Kept
// under the same import path so call sites are unchanged; the native handler is
// registered under that name in MainActivity.kt / AppDelegate.swift.
export 'package:wallet_infra/wallet_infra.dart' show SecureClipboard;
