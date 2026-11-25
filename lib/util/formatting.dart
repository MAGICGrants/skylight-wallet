import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/l10n/shared_strings.dart';

double doubleAmountFromInt(int amount) {
  return amount / 1000000000000;
}

/// What a screen reader says for [address] shown cut to its first [head] and
/// last [tail] characters: "4A1b, ending x9Yz", not the ellipsis between them.
String spokenShortAddress(
  AppLocalizations i18n,
  String address, {
  required int head,
  required int tail,
}) {
  if (address.length <= head + tail + 1) return address;
  return i18n.shared.a11yAddressEnds(
    address.substring(0, head),
    address.substring(address.length - tail),
  );
}
