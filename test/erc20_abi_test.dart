import 'package:flutter_test/flutter_test.dart';
import 'package:spice_wallet/wallets/coins/ethereum/erc20_abi.dart';

void main() {
  // A known checksummed address; calldata always lowercases + left-pads to 32 bytes.
  const addr = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';
  const paddedAddr = '0000000000000000000000005aaeb6053f3e94c9b9a09f33669435e7ef1beaed';

  group('erc20TransferData', () {
    test('encodes selector + address + amount (1 wei)', () {
      expect(
        erc20TransferData(addr, BigInt.one),
        '0xa9059cbb$paddedAddr'
        '0000000000000000000000000000000000000000000000000000000000000001',
      );
    });

    test('encodes 1 DAI (1e18) amount', () {
      expect(
        erc20TransferData(addr, BigInt.parse('1000000000000000000')),
        '0xa9059cbb$paddedAddr'
        '0000000000000000000000000000000000000000000000000de0b6b3a7640000',
      );
    });

    test('rejects malformed addresses', () {
      expect(() => erc20TransferData('0x1234', BigInt.one), throwsArgumentError);
      expect(() => erc20TransferData(addr, BigInt.from(-1)), throwsArgumentError);
    });
  });

  group('erc20BalanceOfData', () {
    test('encodes selector + address', () {
      expect(erc20BalanceOfData(addr), '0x70a08231$paddedAddr');
    });
  });
}
