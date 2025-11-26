import 'package:skylight_wallet/consts.dart' as consts;
import 'package:skylight_wallet/util/dirs.dart';

Future<String> getWalletPath([String? walletFileName]) async {
  var path = (await getAppDir()).path;
  String walletName = walletFileName ?? consts.walletFileName;
  path = '$path/$walletName';
  return path;
}
