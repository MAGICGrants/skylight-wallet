import 'package:skylight_wallet/util/dirs.dart';

Future<String> getWalletPath(String coinSymbol) async {
  final path = (await getAppDir()).path;
  return '$path/mywallet_${coinSymbol.toLowerCase()}';
}
