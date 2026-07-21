import 'package:spice_wallet/util/dirs.dart';

Future<String> getWalletPath(String coinSymbol) async {
  final path = (await getAppDir()).path;
  return '$path/mywallet_${coinSymbol.toLowerCase()}';
}

/// v1 wrote its single Monero wallet to `{appDir}/mywallet` (no coin suffix).
/// Used by the v1→v2 migration to detect and open the legacy wallet.
const legacyWalletFileName = 'mywallet';

Future<String> getLegacyWalletPath() async {
  final path = (await getAppDir()).path;
  return '$path/$legacyWalletFileName';
}
