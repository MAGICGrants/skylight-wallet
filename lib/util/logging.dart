import 'package:flutter/foundation.dart';

enum LogLevel { info, warn, error }

String _timestamp() => DateTime.now().toUtc().toIso8601String();

void log(LogLevel level, String message, [Map<String, dynamic>? meta]) {
  final ts = _timestamp();
  final label = level.toString().split('.').last.toUpperCase();
  final metaStr = (meta == null || meta.isEmpty) ? '' : ' ${meta.toString()}';
  final output = '[$ts] [$label] $message$metaStr';

  if (level == LogLevel.error) {
    debugPrint(output);
  } else {
    if (kDebugMode) debugPrint(output);
  }
}
