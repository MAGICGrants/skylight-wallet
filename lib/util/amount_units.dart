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
