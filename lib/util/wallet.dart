import 'package:path_provider/path_provider.dart';
import 'package:skylight_wallet/consts.dart' as consts;

Future<String> getWalletPath([String? walletFileName]) async {
  var path = (await getApplicationDocumentsDirectory()).path;
  String walletName = walletFileName ?? consts.walletFileName;
  path = '$path/$walletName';
  return path;
}
