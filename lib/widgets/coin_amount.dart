import 'package:flutter/material.dart';

/// Renders a crypto amount with the integer/major-decimal portion in
/// `maxFontSize` and the trailing minor-decimal portion (default last 9
/// digits) in half size, so very small fractional balances stay readable
/// without crowding out the headline figure.
class CoinAmount extends StatelessWidget {
  final double amount;
  final int decimals;
  final double maxFontSize;
  final int smallerDigits;

  const CoinAmount({
    super.key,
    required this.amount,
    required this.maxFontSize,
    required this.decimals,
    required this.smallerDigits,
  });

  @override
  Widget build(BuildContext context) {
    final amountStr = amount.toStringAsFixed(decimals);
    final splitAt = amountStr.length - smallerDigits;
    final hasSplit = splitAt > 0;
    final biggerSlice = hasSplit ? amountStr.substring(0, splitAt) : '';
    final smallerSlice = hasSplit ? amountStr.substring(splitAt) : amountStr;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (biggerSlice.isNotEmpty)
          Text(
            biggerSlice,
            style: TextStyle(fontSize: maxFontSize, fontWeight: FontWeight.w700),
          ),
        Container(
          margin: EdgeInsetsGeometry.only(top: maxFontSize * 0.16),
          child: Text(
            smallerSlice,
            style: TextStyle(fontSize: maxFontSize / 2, fontWeight: FontWeight.w400),
          ),
        ),
      ],
    );
  }
}
