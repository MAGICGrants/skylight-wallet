import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<void> createAppDir() async {
  final appDir = await getAppDir();
  if (!await appDir.exists()) {
    await appDir.create(recursive: true);
  }
}

Future<Directory> getAppDir() async {
  final documentsDir = await getApplicationDocumentsDirectory();
  var appDir = documentsDir;

  if (Platform.isLinux) {
    final homeDir = Platform.environment['HOME'];

    if (homeDir != null) {
      appDir = Directory('$homeDir/.skylight_wallet');
    } else {
      throw Exception('HOME environment variable is not set');
    }
  }

  return appDir;
}
