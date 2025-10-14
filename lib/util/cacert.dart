import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<void> copyCacertToAppDocumentsDir() async {
  final appDocumentsDir = await getApplicationDocumentsDirectory();
  final cacertPath = '${appDocumentsDir.path}/cacert.pem';
  final cacert = await rootBundle.load('assets/cacert.pem');
  await File(cacertPath).writeAsBytes(cacert.buffer.asUint8List(), flush: true);
}

Future<File> getCacertFile() async {
  final appDocumentsDir = await getApplicationDocumentsDirectory();
  final cacertPath = '${appDocumentsDir.path}/cacert.pem';
  return File(cacertPath);
}
