import 'package:flutter/material.dart';

class MoneroAmount extends StatelessWidget {
  final double amount;
  final double maxFontSize;
  final String? prefix;

  const MoneroAmount({
    super.key,
    required this.amount,
    required this.maxFontSize,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    final amountStr = amount.toStringAsFixed(12);
    final smallerSlice = amountStr.substring(amountStr.length - 9);
    final biggerSlice = amountStr.substring(0, amountStr.length - 9);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (prefix != null)
          Text(
            prefix!,
            style: TextStyle(fontSize: maxFontSize, fontWeight: FontWeight.w700),
          ),
        Text(
          biggerSlice,
          style: TextStyle(fontSize: maxFontSize, fontWeight: FontWeight.w700),
        ),
        Container(
          margin: EdgeInsetsGeometry.only(top: maxFontSize * 0.16),
          child: Text(
            smallerSlice,
            style: TextStyle(
              fontSize: maxFontSize / 2,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
