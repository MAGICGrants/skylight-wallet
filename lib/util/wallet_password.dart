import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:skylight_wallet/consts.dart';

String genWalletPassword() {
  final byteLength = 16;
  final rand = Random.secure();
  final bytes = Uint8List.fromList(
    List<int>.generate(byteLength, (_) => rand.nextInt(256)),
  );
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

Future<void> storeWalletPassword(String password) async {
  final storage = FlutterSecureStorage();
  await storage.write(key: walletPasswordStorageKey, value: password);
}

Future<String?> getWalletPassword() async {
  final storage = FlutterSecureStorage();
  return storage.read(key: walletPasswordStorageKey);
}
