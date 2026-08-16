import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'logger.dart';
import 'package:flutter/foundation.dart';

/// Concrete logger that writes log messages to a rotating file on device storage.
/// Uses a simple in‑memory buffer to batch writes and caches the log file.
class FileLogger extends AppLogger {
  static const _maxFileSize = 1024 * 1024; // 1 MB
  static const _maxFiles = 5;

  /// Exposed for testing only.
  @visibleForTesting
  static int get maxFileSizeForTest => _maxFileSize;

  /// Exposed for testing only.
  @visibleForTesting
  static int get maxFilesForTest => _maxFiles;

  /// Returns the current log file. Exposed for testing only.
  @visibleForTesting
  Future<File> logFileForTest() => _logFile();

  FileLogger._();
  static final FileLogger _instance = FileLogger._();
  static FileLogger get instance => _instance;

  // Cached log file reference to avoid repeated directory resolution.
  Future<File>? _cachedLogFile;

  // Simple buffer for asynchronous batched writes.
  final List<String> _writeBuffer = [];
  Timer? _bufferTimer;

  Future<File> _logFile() async {
    if (_cachedLogFile != null) return _cachedLogFile!;
    Directory baseDir;
    try {
      baseDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      baseDir = Directory.systemTemp;
    }
    final logsDir = Directory('${baseDir.path}/logs');
    if (!await logsDir.exists()) await logsDir.create(recursive: true);
    final file = File('${logsDir.path}/tradeverse.log');
    _cachedLogFile = Future.value(file);
    return file;
  }

  // Add a message to the buffer and schedule a write after a short debounce.
  void _bufferWrite(String message) {
    _writeBuffer.add(message);
    _bufferTimer?.cancel();
    // Flush after 100 ms of inactivity.
    _bufferTimer = Timer(const Duration(milliseconds: 100), _flushBuffer);
  }

  Future<void> _flushBuffer() async {
    if (_writeBuffer.isEmpty) return;
    final file = await _logFile();
    if (await file.exists()) {
      final size = await file.length();
      if (size > _maxFileSize) await _rotate(file);
    }
    final combined = '${_writeBuffer.join('\n')}\n';
    _writeBuffer.clear();
    await file.writeAsString(combined, mode: FileMode.append);
  }

  Future<void> _rotate(File current) async {
    final dir = current.parent;
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.log'))
        .cast<File>()
        .toList();
    files.sort((a, b) => a.statSync().changed.compareTo(b.statSync().changed));
    if (files.length >= _maxFiles) {
      await files.first.delete();
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newPath = '${dir.path}/tradeverse_$timestamp.log';
    await current.copy(newPath);
    await current.writeAsString('');
  }

  @override
  void log(LogLevel level, String message, [Object? error, StackTrace? stackTrace]) {
    super.log(level, message, error, stackTrace);
    if (kIsWeb) return;
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final prefix = level.prefix;
    final levelName = level.name.padRight(5);
    final logMessage = '[$timestamp] $prefix [$levelName] $message';
    _bufferWrite(logMessage);
    if (error != null) _bufferWrite('  Error: $error');
    if (stackTrace != null) _bufferWrite('  Stack trace:\n$stackTrace');
  }
  
  /// Reset cache and buffer for testing isolation.
  @visibleForTesting
  void resetForTesting() {
    _cachedLogFile = null;
    _writeBuffer.clear();
    _bufferTimer?.cancel();
    _bufferTimer = null;
  }
}

/// Global file logger instance for convenience.
final fileLogger = FileLogger.instance;
