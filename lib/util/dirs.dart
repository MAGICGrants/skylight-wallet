import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:monero_light_wallet/consts.dart' as consts;

Future<Directory> getTorDataDir() async {
  final documentsDirPath = (await getApplicationDocumentsDirectory());
  final torDataDirName = consts.torDataDirName;
  final torDataDir = Directory('${documentsDirPath.path}/$torDataDirName');
  return torDataDir;
}
