import 'package:flutter_test/flutter_test.dart';
import 'package:skylight_wallet/wallets/coins/ethereum/ethereum_wallet_open.dart';

void main() {
  group('deriveEthereumKeys', () {
    // Well-known Foundry/Hardhat default mnemonic, account 0 (m/44'/60'/0'/0/0).
    const mnemonic = 'test test test test test test test test test test test junk';

    test('derives the known address', () {
      expect(
        deriveEthereumKeys(mnemonic).address,
        '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
      );
    });

    test('derives the known private key', () {
      expect(
        deriveEthereumKeys(mnemonic).privateKeyHex,
        'ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
      );
    });
  });
}
