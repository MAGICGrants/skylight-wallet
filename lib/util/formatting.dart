double doubleAmountFromInt(int amount) {
  return amount / 1000000000000;
}

/// Splits an address into visually distinct prefix/suffix regions so users
/// can verify the start and end regardless of coin or address format.
class AddressDisplayParts {
  final String prefix;
  final String middle;
  final String suffix;

  const AddressDisplayParts(this.prefix, this.middle, this.suffix);
}

AddressDisplayParts addressDisplayParts(String address) {
  if (address.isEmpty) {
    return AddressDisplayParts('', '', '');
  }
  if (address.length <= 12) {
    return AddressDisplayParts(address, '', '');
  }

  final highlight = switch (address.length) {
    <= 20 => 4,
    <= 40 => 6,
    <= 60 => 8,
    _ => 10,
  };

  if (address.length <= highlight * 2) {
    final mid = address.length ~/ 2;
    return AddressDisplayParts(address.substring(0, mid), '', address.substring(mid));
  }

  return AddressDisplayParts(
    address.substring(0, highlight),
    address.substring(highlight, address.length - highlight),
    address.substring(address.length - highlight),
  );
}
