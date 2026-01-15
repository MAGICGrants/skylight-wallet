import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/util/dirs.dart';

enum LogLevel { info, warn, error }

class _LogQueue {
  Future<void>? _lastWrite;

  Future<void> add(Future<void> Function() operation) {
    _lastWrite = _lastWrite?.then((_) => operation()) ?? operation();
    return _lastWrite!;
  }
}

final _logQueue = _LogQueue();

String _timestamp() => DateTime.now().toUtc().toIso8601String();

Future<File> _getLogFile() async {
  Directory? directory;

  // Get external storage directory for Android, or documents directory for iOS
  if (Platform.isAndroid) {
    directory = await getExternalStorageDirectory();
  } else {
    directory = await getAppDir();
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
    } else {
      directory = await getAppDir();
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

Future<void> log(LogLevel level, String message, [Map<String, dynamic>? meta]) async {
  final verboseLoggingEnabled =
      await SharedPreferencesService.get<bool>(SharedPreferencesKeys.verboseLoggingEnabled) ??
      false;

  if (level == LogLevel.info && !verboseLoggingEnabled) {
    if (!verboseLoggingEnabled) {
      return;
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
    _logQueue.add(() async {
      try {
        final file = await _getLogFile();
        await file.writeAsString('$output\n', mode: FileMode.append);
      } catch (error) {
        debugPrint('Failed to write log to file: $error');
      }
    });
  }
}

class LogFileInfo {
  final String path;
  final String name;
  final DateTime modified;
  final int size;

  LogFileInfo({required this.path, required this.name, required this.modified, required this.size});
}

/// Returns a list of available log files sorted by date (newest first)
Future<List<LogFileInfo>> getLogFiles() async {
  Directory? directory;

  if (Platform.isAndroid) {
    directory = await getExternalStorageDirectory();
  } else {
    directory = await getAppDir();
  }

  if (directory == null) {
    return [];
  }

  final logsDir = Directory('${directory.path}/logs');
  if (!await logsDir.exists()) {
    return [];
  }

  final files = await logsDir.list().toList();
  final logFiles = <LogFileInfo>[];

  for (var entity in files) {
    if (entity is File && entity.path.endsWith('.txt')) {
      final stat = await entity.stat();
      final name = entity.path.split('/').last;
      logFiles.add(
        LogFileInfo(path: entity.path, name: name, modified: stat.modified, size: stat.size),
      );
    }
  }

  // Sort by date (newest first)
  logFiles.sort((a, b) => b.modified.compareTo(a.modified));
  return logFiles;
}

/// Exports selected log files via the system share sheet (iOS/Android)
Future<void> exportLogFiles(List<LogFileInfo> files) async {
  if (files.isEmpty) {
    throw Exception('No log files selected');
  }

  try {
    final xFiles = files.map((f) => XFile(f.path)).toList();
    await SharePlus.instance.share(ShareParams(files: xFiles));
  } catch (error) {
    debugPrint('Failed to export logs: $error');
    rethrow;
  }
}
