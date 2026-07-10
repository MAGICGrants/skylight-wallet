import 'dart:math';
import 'dart:typed_data';

import 'package:skylight_wallet/consts.dart';
import 'package:skylight_wallet/util/secure_storage.dart';

String genWalletPassword() {
  final byteLength = 16;
  final rand = Random.secure();
  final bytes = Uint8List.fromList(List<int>.generate(byteLength, (_) => rand.nextInt(256)));
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

Future<void> storeMobileWalletPassword(String password) async {
  await secureStorage.write(key: walletPasswordStorageKey, value: password);
}

Future<String?> getMobileWalletPassword() async {
  return secureStorage.read(key: walletPasswordStorageKey);
}

Future<void> deleteMobileWalletPassword() async {
  await secureStorage.delete(key: walletPasswordStorageKey);
}
