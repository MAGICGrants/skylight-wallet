/// Parses restore QR payloads. Accepts the URI format
/// (`monero:`, `monero-wallet:` or `monero_wallet:` with `seed`/`height` query
/// params) as well as a bare seed phrase.
library;

const _moneroRestoreSchemes = {'monero', 'monero-wallet', 'monero_wallet'};

class ParsedRestoreQr {
  final String seed;
  final int? restoreHeight;

  const ParsedRestoreQr({required this.seed, this.restoreHeight});
}

ParsedRestoreQr? parseRestoreQr(String raw) {
  final code = raw.trim();
  if (code.isEmpty) return null;

  final colon = code.indexOf(':');
  if (colon > 0) {
    final scheme = code.substring(0, colon).toLowerCase();
    if (_moneroRestoreSchemes.contains(scheme)) {
      final query = code.substring(colon + 1).replaceAll('?', '&');
      final params = _parseQuery(query);
      final seed = (params['seed'] ?? '').trim();
      if (seed.isEmpty) return null;
      final heightStr = params['height'] ?? params['restoreHeight'];
      final height = heightStr != null ? int.tryParse(heightStr.trim()) : null;
      return ParsedRestoreQr(seed: seed, restoreHeight: height);
    }
  }

  // Not a recognized URI — treat the whole payload as a seed phrase.
  return ParsedRestoreQr(seed: code);
}

/// Builds a restore payload (`monero_wallet:?seed=...&height=...`)
/// for encoding into a QR code. The seed is URL-encoded so spaces survive.
String buildRestoreQr({required String seed, int? height}) {
  final buffer = StringBuffer('monero_wallet:?seed=${Uri.encodeQueryComponent(seed)}');
  if (height != null) buffer.write('&height=$height');
  return buffer.toString();
}

Map<String, String> _parseQuery(String query) {
  final result = <String, String>{};
  for (final pair in query.split('&')) {
    if (pair.isEmpty) continue;
    final eq = pair.indexOf('=');
    if (eq < 0) continue;
    final key = pair.substring(0, eq);
    final value = pair.substring(eq + 1);
    try {
      result[key] = Uri.decodeQueryComponent(value);
    } catch (_) {
      result[key] = value;
    }
  }
  return result;
}
