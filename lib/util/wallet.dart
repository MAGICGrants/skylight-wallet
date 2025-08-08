import 'package:path_provider/path_provider.dart';
import 'package:monero_light_wallet/consts.dart' as consts;

Future<String> getWalletPath() async {
  var path = (await getApplicationDocumentsDirectory()).path;
  String walletName = consts.walletFileName;
  path = '$path/$walletName';
  return path;
}
