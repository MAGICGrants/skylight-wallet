import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';

enum LogLevel { info, warn, error }

String _timestamp() => DateTime.now().toUtc().toIso8601String();

Future<File> _getLogFile() async {
  Directory? directory;

  // Get external storage directory for Android, or documents directory for iOS
  if (Platform.isAndroid) {
    directory = await getExternalStorageDirectory();
  } else if (Platform.isIOS) {
    directory = await getApplicationDocumentsDirectory();
  } else {
    directory = await getApplicationDocumentsDirectory();
  }

  if (directory == null) {
    throw Exception('Could not access storage directory');
  }

  // Create logs subdirectory
  final logsDir = Directory('${directory.path}/logs');
  if (!await logsDir.exists()) {
    await logsDir.create(recursive: true);
  }

  // Create filename with current date (YYYY-MM-DD)
  final dateStr = DateTime.now().toIso8601String().split('T').first;
  final filePath = '${logsDir.path}/log_$dateStr.txt';

  return File(filePath);
}

Future<void> cleanOldLogFiles() async {
  try {
    Directory? directory;

    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    if (directory == null) {
      return;
    }

    final logsDir = Directory('${directory.path}/logs');
    if (!await logsDir.exists()) {
      return;
    }

    // Get current time and calculate cutoff date
    const daysToKeep = 30;
    final now = DateTime.now();
    final cutoffDate = now.subtract(const Duration(days: daysToKeep));

    // List all files in logs directory
    final files = await logsDir.list().toList();

    for (var entity in files) {
      if (entity is File) {
        final stat = await entity.stat();
        final modifiedDate = stat.modified;

        // Delete file if it's older than the cutoff date
        if (modifiedDate.isBefore(cutoffDate)) {
          await entity.delete();
          debugPrint('Deleted old log file: ${entity.path}');
        }
      }
    }
  } catch (error) {
    debugPrint('Failed to clean old logs: $error');
  }
}

void log(LogLevel level, String message, [Map<String, dynamic>? meta]) async {
  // Check if verbose logging is enabled for info-level logs
  final verboseLoggingEnabled =
      await SharedPreferencesService.get<bool>(
        SharedPreferencesKeys.verboseLoggingEnabled,
      ) ??
      false;

  if (level == LogLevel.info && !verboseLoggingEnabled) {
    if (!verboseLoggingEnabled) {
      return; // Skip info logs when verbose logging is disabled
    }
  }

  final ts = _timestamp();
  final label = level.toString().split('.').last.toUpperCase();
  final metaStr = (meta == null || meta.isEmpty) ? '' : ' ${meta.toString()}';
  final output = '[$ts] [$label] $message $metaStr';

  if (level == LogLevel.error) {
    debugPrint(output);
  } else {
    if (kDebugMode) debugPrint(output);
  }

  if (verboseLoggingEnabled) {
    _getLogFile()
        .then((file) {
          file.writeAsString('$output\n', mode: FileMode.append);
        })
        .catchError((error) {
          debugPrint('Failed to write log to file: $error');
        });
  }
}
