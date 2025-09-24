import 'package:flutter/material.dart';

class FiatAmount extends StatelessWidget {
  final String prefix;
  final double amount;
  final double maxFontSize;

  const FiatAmount({
    super.key,
    required this.prefix,
    required this.amount,
    required this.maxFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$prefix${amount.toInt()}',
          style: TextStyle(fontSize: maxFontSize, fontWeight: FontWeight.w400),
        ),
        Container(
          margin: EdgeInsets.only(top: maxFontSize * 0.16),
          child: Text(
            (amount % 1).toStringAsFixed(2).substring(2),
            style: TextStyle(
              fontSize: maxFontSize / 2,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ],
    );
  }
}
