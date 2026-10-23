import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_domain/wallet_domain.dart';
import 'package:wallet_infra/testing.dart';
import 'package:wallet_infra/wallet_infra.dart';
import 'package:wallet_monero/wallet_monero.dart';
import 'package:skylight_wallet/models/monero_wallet_adapter.dart';

/// Skylight's send screen resolves names through this adapter, so the
/// OpenAlias setting (Settings > Security and privacy) must reach it the same
/// way it does in Spice: Clearnet-Only resolves with Tor off.
void main() {
  late Directory tmp;
  late MoneroWalletAdapter adapter;
  late List<int?> ports;

  final address = '4${'a' * 94}';

  setUpAll(() => WalletFileCrypto.kdf = const FastTestPbkdf2());
  tearDownAll(() => WalletFileCrypto.kdf = const WebCryptoPbkdf2());

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('openalias_mode');
    SharedPreferencesService.store = MemoryPreferenceStore();
    WalletSecrets.store = MemorySecretStore();
    WalletAppConfig.install(WalletAppConfig.skylight, directories: FixedDirectories(tmp));
    useTestCaBundle();
    WalletLog.sink = MemoryLogSink();
    final backend = FakeMoneroBackend()..addressValidator = (a, _) => a == address;
    final wallet = MoneroWallet(backend: backend);
    backend.existingWalletPaths.add(await wallet.walletPathForType('lws'));
    await wallet.openExisting(password: 'pw');
    adapter = MoneroWalletAdapter(wallet, readStoredSeed: () async => null);

    ports = [];
    CryptoWallet.aliasResolver =
        ({
          required String alias,
          required String network,
          required String asset,
          required int? socksPort,
          String? nativeAsset,
        }) async {
          ports.add(socksPort);
          return ResolvedAlias(address: address);
        };
    await TorSettingsService.sharedInstance.save(torMode: TorMode.disabled);
  });

  tearDown(() {
    CryptoWallet.resetInjectablesForTesting();
    TorSettingsService.sharedInstance.resetForTesting();
    WalletAppConfig.resetForTesting();
    CaBundle.resetForTesting();
    SharedPreferencesService.resetForTesting();
    tmp.deleteSync(recursive: true);
  });

  test('Clearnet-Only resolves with Tor off, without a proxy', () async {
    await OpenAliasMode.clearnet.save();
    final resolved = await adapter.resolveOpenAlias('donate.example.org');
    expect(resolved?.address, address);
    expect(ports, [null]);
  });

  test('Tor-Only with Tor off resolves nothing, and never asks', () async {
    expect(await adapter.resolveOpenAlias('donate.example.org'), isNull);
    expect(ports, isEmpty);
  });

  test('Disabled resolves nothing, and never asks', () async {
    await OpenAliasMode.disabled.save();
    expect(await adapter.resolveOpenAlias('donate.example.org'), isNull);
    expect(ports, isEmpty);
  });
}
