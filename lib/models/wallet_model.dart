import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:monero/monero.dart' as monero;

class WalletModel with ChangeNotifier {
  final monero.WalletManager _walletManager =
      monero.WalletManagerFactory_getWalletManager();

  late monero.wallet _wallet;

  monero.wallet get wallet => _wallet;

  void _connectToDaemon() {
    monero.Wallet_init(_wallet, daemonAddress: '192.168.255.114:18081');
    monero.Wallet_setTrustedDaemon(_wallet, arg: true);
    monero.Wallet_connectToDaemon(_wallet);
    // monero.Wallet_refresh(_wallet);
    // monero.Wallet_startRefresh(_wallet);
    monero.Wallet_refreshAsync(_wallet);
  }

  Future<void> restoreFromMnemonic(
    String mnemonic,
    int restoreHeight, [
    String passphrase = '',
  ]) async {
    final path = (await getApplicationDocumentsDirectory()).path;

    print(path);

    _wallet = monero.WalletManager_recoveryWallet(
      _walletManager,
      mnemonic: mnemonic,
      password: 'pass',
      path: '$path/wallet',
      restoreHeight: restoreHeight,
      seedOffset: passphrase,
    );

    _connectToDaemon();

    notifyListeners();
  }

  bool isConnected() {
    return monero.Wallet_connected(_wallet) != 0;
  }

  bool isSynced() {
    return monero.Wallet_synchronized(_wallet);
  }

  String getAddress() {
    return monero.Wallet_address(_wallet, accountIndex: 0);
  }

  int getHeight() {
    return monero.Wallet_blockChainHeight(_wallet);
  }

  double getBalance() {
    return monero.Wallet_balance(_wallet, accountIndex: 0) / 1000000000000;
  }
}
