import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Centralized logger for ResilienceMesh on-device diagnostics.
/// Writes to both stdout/console and a persistent on-device log file.
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  File? _logFile;
  final List<String> _inMemoryLogs = [];

  Future<void> init() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      _logFile = File('${docs.path}/resiliencemesh_debug.log');
      log('=== ResilienceMesh Debug Log Initialized at ${DateTime.now().toIso8601String()} ===');
    } catch (e) {
      debugPrint('LoggerService init error: $e');
    }
  }

  void log(String message) {
    final timeStr = DateTime.now().toIso8601String().split('T').last;
    final formatted = '[$timeStr] $message';
    debugPrint(formatted);
    _inMemoryLogs.add(formatted);
    if (_inMemoryLogs.length > 1000) _inMemoryLogs.removeAt(0);

    try {
      _logFile?.writeAsStringSync('$formatted\n', mode: FileMode.append);
    } catch (_) {}
  }

  Future<String> getLogDump() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        final content = await _logFile!.readAsString();
        if (content.trim().isNotEmpty) return content;
      }
    } catch (_) {}
    return _inMemoryLogs.join('\n');
  }

  Future<void> clearLogs() async {
    _inMemoryLogs.clear();
    try {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.writeAsString('=== Log Cleared ===\n');
      }
    } catch (_) {}
  }
}

final logger = LoggerService();
