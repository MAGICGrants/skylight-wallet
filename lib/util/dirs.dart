import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:skylight_wallet/util/logging.dart';

Future<void> cleanTorDirectoriesOnIOS() async {
  if (!Platform.isIOS) return;

  final documentsDir = await getApplicationDocumentsDirectory();
  final torCacheDir = Directory('${documentsDir.path}/tor_cache');
  final torStateDir = Directory('${documentsDir.path}/tor_state');

  if (await torCacheDir.exists()) {
    try {
      await torCacheDir.delete(recursive: true);
      log(LogLevel.info, 'Deleted tor_cache directory');
    } catch (e) {
      log(LogLevel.error, 'Failed to delete tor_cache directory: $e');
    }
  }

  if (await torStateDir.exists()) {
    try {
      await torStateDir.delete(recursive: true);
      log(LogLevel.info, 'Deleted tor_state directory');
    } catch (e) {
      log(LogLevel.error, 'Failed to delete tor_state directory: $e');
    }
  }
}

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
  } else if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'];

    if (appData != null) {
      appDir = Directory('$appData/MAGIC Grants/Skylight Wallet');
    } else {
      throw Exception('APPDATA environment variable is not set');
    }
  }

  return appDir;
}
