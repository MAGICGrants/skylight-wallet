// Classification of a connection address (node/LWS/electrum host:port) into the
// transport it implies — shared by the connection form and the asset screen so
// both label a connection the same way.

final ipAddressRegex = RegExp(
  r'(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)(?:\.(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)){3}(?::\d{1,5})?$',
);
final domainAddressRegex = RegExp(
  r'(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}(?::\d{1,5})?$',
);
final onionAddressRegex = RegExp(r'[a-z2-7]{56}.onion(:\d{1,5})?$');

/// A private/LAN IPv4 host (RFC 1918 ranges + loopback).
bool isLocalIp(String host) {
  if (host.startsWith('192.168.') || host.startsWith('10.') || host.startsWith('127.')) {
    return true;
  }
  final match = RegExp(r'^172\.(\d{1,3})\.').firstMatch(host);
  if (match != null) {
    final second = int.tryParse(match.group(1)!) ?? 0;
    return second >= 16 && second <= 31;
  }
  return false;
}

/// True when the address is a clearnet domain — the only case that speaks HTTPS.
/// Onion, IP and `.local` hosts do not.
bool addressUsesSsl(String value) {
  final host = value.split(':').first;
  if (onionAddressRegex.hasMatch(value)) return false;
  if (ipAddressRegex.hasMatch(value)) return false;
  if (host.endsWith('.local')) return false;
  return domainAddressRegex.hasMatch(value);
}

/// True for a LAN address — a private IP or a `.local` host.
bool addressIsLocal(String value) {
  final host = value.split(':').first;
  if (ipAddressRegex.hasMatch(value)) return isLocalIp(host);
  return host.endsWith('.local');
}
