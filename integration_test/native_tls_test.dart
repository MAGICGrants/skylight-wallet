import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wallet_monero/testing.dart';

/// TLS against the native library this app ships, on the platform the test
/// runs on: CI runs it on an Android emulator, an iOS simulator, Linux and
/// Windows. The checks themselves live in wallet-core (`nativeTlsChecks`) and
/// stand up their own loopback servers, so nothing leaves the machine.
///
///   `flutter test integration_test/native_tls_test.dart -d DEVICE`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the shipped CA bundle reaches the app directory', (_) => checkShippedCaBundle());

  for (final check in nativeTlsChecks()) {
    testWidgets(check.name, (_) async {
      final dir = await Directory.systemTemp.createTemp('native_tls');
      try {
        await check.run(dir);
      } finally {
        await dir.delete(recursive: true);
      }
    });
  }
}
