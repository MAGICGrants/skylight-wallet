import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:polyseed/polyseed.dart';
import 'package:wallet_domain/wallet_domain.dart';
import 'package:wallet_infra/testing.dart';
import 'package:wallet_infra/wallet_infra.dart';
import 'package:wallet_monero/wallet_monero.dart';
import 'package:wallet_monero_oxide/wallet_monero_oxide.dart';

/// The CA bundle and the Monero library, inside the real app on the platform
/// the test runs on: CI runs it on an Android emulator, an iOS simulator,
/// Linux and Windows, so it sees the app's own asset bundle and the library
/// cargokit built for that platform.
///
/// The library's TLS stack (rustls) has no roots of its own: it trusts exactly
/// the CA file `setCaFilePath` hands it. The checks hold it to that against a
/// loopback server whose chain goes to a throwaway root ([TestPki]), so
/// nothing leaves the machine. That `MoneroWallet` hands the library this
/// bundle before every TLS connection is wallet-core's unit test
/// (`monero_tls_config_test.dart`).
///
///   `flutter test integration_test/ca_bundle_test.dart -d DEVICE`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    // The app sets up its directory in main(), which this test does not run,
    // so a temporary directory stands in for it.
    dir = await Directory.systemTemp.createTemp('ca_bundle');
    WalletAppConfig.install(WalletAppConfig.skylight, directories: FixedDirectories(dir));
    CaBundle.resetForTesting();
  });

  tearDown(() async {
    CaBundle.resetForTesting();
    WalletAppConfig.resetForTesting();
    await dir.delete(recursive: true);
  });

  testWidgets('the shipped CA bundle reaches the app directory', (_) async {
    final pem = await File(await CaBundle.path()).readAsString();
    expect(RegExp('-----BEGIN CERTIFICATE-----').allMatches(pem), hasLength(greaterThan(100)));
  });

  testWidgets('the Monero library refuses a CA file with no certificate', (_) async {
    final empty = File('${dir.path}/empty.pem')..writeAsStringSync('');
    await _withWallet(MoneroManagerKind.node, dir, (backend, wallet) async {
      expect(await backend.setCaFilePath(wallet, empty.path), isFalse);
    });
  });

  for (final kind in MoneroManagerKind.values) {
    testWidgets('${kind.name}: accepts a server the CA file vouches for', (_) async {
      final testRoot = File('${dir.path}/test-root-ca.pem')..writeAsStringSync(TestPki.rootCa);
      final server = await _server();
      try {
        expect(await _connect(kind, dir, server, testRoot.path), isTrue);
        expect(server.handshakes, greaterThan(0));
        expect(server.requests, isNotEmpty);
      } finally {
        await server.close();
      }
    });

    testWidgets('${kind.name}: trusts nothing beyond the shipped bundle', (_) async {
      final server = await _server();
      try {
        expect(await _connect(kind, dir, server, await CaBundle.path()), isTrue);
        // The library reached the server and gave up during the handshake.
        await _settle(() => server.failedHandshakes > 0);
        expect(server.failedHandshakes, greaterThan(0));
        expect(server.handshakes, 0);
        expect(server.requests, isEmpty);
      } finally {
        await server.close();
      }
    });
  }
}

Future<TlsTestServer> _server() =>
    TlsTestServer.start(chainPem: TestPki.serverChain, keyPem: TestPki.serverKey);

var _wallets = 0;

/// Runs [body] on a throwaway wallet from [kind]'s manager.
Future<T> _withWallet<T>(
  MoneroManagerKind kind,
  Directory dir,
  Future<T> Function(MoneroBackend backend, NativeHandle wallet) body,
) async {
  const backend = OxideMoneroBackend();
  final manager = await backend.getWalletManager(kind);
  final wallet = await backend.createWalletFromPolyseed(
    manager,
    mnemonic: Polyseed.create().encode(
      PolyseedLang.getByEnglishName('English'),
      PolyseedCoin.POLYSEED_MONERO,
    ),
    seedOffset: '',
    restoreHeight: 0,
    path: '${dir.path}/wallet_${_wallets++}',
    password: 'ca-bundle-test',
    newWallet: true,
    kdfRounds: 1,
  );
  try {
    return await body(backend, wallet);
  } finally {
    await backend.closeWallet(manager, wallet, store: false);
  }
}

/// Hands a throwaway wallet [caFile] and, if the library takes it, connects
/// once to [server]. Answers whether the library took the file; what reached
/// the server is the verdict on the connection.
Future<bool> _connect(
  MoneroManagerKind kind,
  Directory dir,
  TlsTestServer server,
  String caFile,
) => _withWallet(kind, dir, (backend, wallet) async {
  if (!await backend.setCaFilePath(wallet, caFile)) return false;
  await backend.init(
    wallet,
    daemonAddress: 'https://127.0.0.1:${server.port}',
    proxyAddress: '',
    useSsl: true,
    lightWallet: kind == MoneroManagerKind.lws,
  );
  await backend.connectToDaemon(wallet);
  return true;
});

/// The server handles the client's hang-up on this isolate's event loop, which
/// can run after the library's call has already returned.
Future<void> _settle(bool Function() done) async {
  for (var i = 0; i < 50 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}
