// Minimal ERC-20 ABI calldata builders. Each returns a 0x-prefixed hex string
// suitable for an `eth_call`/transaction `data` field — manual encoding (no ABI
// JSON): 4-byte selector + 32-byte left-padded args.

/// `transfer(address,uint256)` — selector `0xa9059cbb`.
String erc20TransferData(String to, BigInt amount) =>
    '0xa9059cbb${_padAddress(to)}${_padUint(amount)}';

/// `balanceOf(address)` — selector `0x70a08231`.
String erc20BalanceOfData(String owner) => '0x70a08231${_padAddress(owner)}';

String _padAddress(String address) {
  var hex = address.toLowerCase();
  if (hex.startsWith('0x')) hex = hex.substring(2);
  if (hex.length != 40 || !RegExp(r'^[0-9a-f]+$').hasMatch(hex)) {
    throw ArgumentError('Invalid address: $address');
  }
  return hex.padLeft(64, '0');
}

String _padUint(BigInt value) {
  if (value < BigInt.zero) throw ArgumentError('Negative amount: $value');
  final hex = value.toRadixString(16);
  if (hex.length > 64) throw ArgumentError('Amount overflows uint256: $value');
  return hex.padLeft(64, '0');
}
