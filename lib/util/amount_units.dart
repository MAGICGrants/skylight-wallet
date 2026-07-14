/// Converts a decimal amount string to integer base units (e.g. ETH → wei)
/// without going through `double`, which loses precision above 2^53 for
/// 18-decimal values. Extra fractional digits beyond [decimals] are truncated.
BigInt decimalToBaseUnits(String amount, int decimals) {
  final s = amount.trim();
  if (s.isEmpty) return BigInt.zero;

  final parts = s.split('.');
  if (parts.length > 2) throw FormatException('Invalid amount: $amount');

  final intPart = parts[0].isEmpty ? '0' : parts[0];
  var fracPart = parts.length == 2 ? parts[1] : '';
  fracPart = fracPart.length > decimals
      ? fracPart.substring(0, decimals)
      : fracPart.padRight(decimals, '0');

  return BigInt.parse('$intPart$fracPart');
}

/// Inverse of [decimalToBaseUnits]: renders integer base units as a decimal
/// string, trimming trailing fractional zeros. Used to fill the amount field
/// from an exact balance without going through `double`.
String baseUnitsToDecimalString(BigInt units, int decimals) {
  if (decimals <= 0) return units.toString();
  final negative = units.isNegative;
  final digits = units.abs().toString().padLeft(decimals + 1, '0');
  final intPart = digits.substring(0, digits.length - decimals);
  final fracPart = digits.substring(digits.length - decimals).replaceAll(RegExp(r'0+$'), '');
  final result = fracPart.isEmpty ? intPart : '$intPart.$fracPart';
  return negative ? '-$result' : result;
}
