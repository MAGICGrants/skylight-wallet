import 'package:flutter_test/flutter_test.dart';
import 'package:spice_wallet/wallets/coins/bitcoin/bitcoin_fees.dart';

void main() {
  group('feeRateForBlocks', () {
    test('empty histogram → floor', () {
      expect(feeRateForBlocks(const [], 1, floorSatVb: 1), 1);
    });

    test('picks the rate that fills one block', () {
      // 0.6M vbytes @100, then 0.6M @50 → crosses 1M block in the 50 bucket.
      final hist = [
        [100, 600000],
        [50, 600000],
        [10, 2000000],
      ];
      expect(feeRateForBlocks(hist, 1), 50);
    });

    test('higher target reaches into lower-fee buckets', () {
      final hist = [
        [100, 600000],
        [50, 600000],
        [10, 2000000],
      ];
      // 3 blocks = 3M capacity: 0.6+0.6+2.0 = 3.2M crosses in the 10 bucket.
      expect(feeRateForBlocks(hist, 3), 10);
    });

    test('uncongested mempool smaller than capacity → floor', () {
      final hist = [
        [100, 100000],
        [50, 100000],
      ];
      expect(feeRateForBlocks(hist, 1, floorSatVb: 2), 2);
    });

    test('floors a sub-floor feerate result', () {
      final hist = [
        [3, 600000],
        [1, 600000], // crosses 1M here at feerate 1
      ];
      expect(feeRateForBlocks(hist, 1, floorSatVb: 2), 2);
    });

    test('invalid targetBlocks → floor', () {
      expect(
        feeRateForBlocks(
          [
            [100, 2000000],
          ],
          0,
          floorSatVb: 1,
        ),
        1,
      );
    });
  });
}
