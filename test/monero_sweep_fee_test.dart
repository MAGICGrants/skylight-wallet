import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_domain/wallet_domain.dart';
import 'package:wallet_infra/testing.dart';
import 'package:wallet_infra/wallet_infra.dart';
import 'package:wallet_monero/wallet_monero.dart';
import 'package:skylight_wallet/models/monero_wallet_adapter.dart';

/// estimateFee prices a normal send; when no estimate comes back (a sweep, or
/// some states) the adapter falls back to building the tx.
void main() {
  late Directory tmp;
  late FakeMoneroBackend backend;
  late MoneroWalletAdapter adapter;

  final dest = '4${'a' * 94}';

  setUpAll(() => WalletFileCrypto.kdf = const FastTestPbkdf2());
  tearDownAll(() => WalletFileCrypto.kdf = const WebCryptoPbkdf2());

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('monero_sweep_fee');
    SharedPreferencesService.store = MemoryPreferenceStore();
    WalletSecrets.store = MemorySecretStore();
    WalletAppConfig.install(WalletAppConfig.skylight, directories: FixedDirectories(tmp));
    useTestCaBundle();
    WalletLog.sink = MemoryLogSink();
    backend = FakeMoneroBackend();
    final wallet = MoneroWallet(backend: backend);
    backend.existingWalletPaths.add(await wallet.walletPathForType('lws'));
    await wallet.openExisting(password: 'pw');
    adapter = MoneroWalletAdapter(wallet, readStoredSeed: () async => null);
  });

  tearDown(() {
    WalletAppConfig.resetForTesting();
    CaBundle.resetForTesting();
    SharedPreferencesService.resetForTesting();
    tmp.deleteSync(recursive: true);
  });

  test('normal send: fee comes from the native estimate', () async {
    backend.feeEstimate = BigInt.from(30000000);
    backend.pendingFee = BigInt.from(12345);
    // Estimate is used; the tx is not built.
    expect(await adapter.estimateFee(dest, '1.0', priority: 1), 30000000);
  });

  test('no estimate returned: falls back to the built-tx fee', () async {
    backend.feeEstimate = null;
    backend.pendingFee = BigInt.from(12345);
    expect(await adapter.estimateFee(dest, '1.0', priority: 1), 12345);
  });

  test('sweep: always priced from the built tx', () async {
    backend.feeEstimate = BigInt.from(30000000);
    backend.pendingFee = BigInt.from(12345);
    expect(await adapter.estimateFee(dest, '1.0', priority: 1, isSweepAll: true), 12345);
  });
}
