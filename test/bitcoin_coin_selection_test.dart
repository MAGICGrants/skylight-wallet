import 'package:flutter_test/flutter_test.dart';
import 'package:spice_wallet/wallets/coins/bitcoin/bitcoin_coin_selection.dart';

int _sum(List<int> values, List<int> idx) => idx.fold(0, (s, i) => s + values[i]);

void main() {
  group('branchAndBoundSelect', () {
    test('exact match, no change window', () {
      final v = [1, 2, 3, 4];
      final sel = branchAndBoundSelect(effectiveValues: v, target: 7, costOfChange: 0);
      expect(sel, isNotNull);
      expect(_sum(v, sel!), 7); // {3,4}
    });

    test('within costOfChange window', () {
      final v = [5000, 3000, 2000];
      // target 6000, window up to 6500 → {5000,2000}=7000 too big; {5000,3000}=8000;
      // {3000,2000}=5000 < target. Only sets >=6000 and <=6500: none exact, so null.
      expect(branchAndBoundSelect(effectiveValues: v, target: 6000, costOfChange: 500), isNull);
    });

    test('accepts overshoot inside window', () {
      final v = [5000, 1200];
      // target 6000, window 6000..6400. {5000,1200}=6200 in window.
      final sel = branchAndBoundSelect(effectiveValues: v, target: 6000, costOfChange: 400);
      expect(sel, isNotNull);
      expect(_sum(v, sel!), 6200);
    });

    test('single utxo exact', () {
      final sel = branchAndBoundSelect(effectiveValues: [10000], target: 10000, costOfChange: 0);
      expect(sel, [0]);
    });

    test('returns null when total below target', () {
      expect(
        branchAndBoundSelect(effectiveValues: [100, 200], target: 1000, costOfChange: 50),
        isNull,
      );
    });

    test('empty / non-positive target', () {
      expect(branchAndBoundSelect(effectiveValues: [], target: 100, costOfChange: 0), isNull);
      expect(branchAndBoundSelect(effectiveValues: [1, 2], target: 0, costOfChange: 0), isNull);
    });

    test('selected indices map back to original order', () {
      // Smallest value is the match; ensure original index returned, not sorted.
      final v = [9000, 50, 8000];
      final sel = branchAndBoundSelect(effectiveValues: v, target: 50, costOfChange: 0);
      expect(sel, [1]);
    });
  });
}
