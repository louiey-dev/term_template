import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// State for the file logging service.
class FileLoggerState {
  const FileLoggerState({this.isLogging = false, this.timestampEnabled = true});

  final bool isLogging;
  final bool timestampEnabled;

  FileLoggerState copyWith({bool? isLogging, bool? timestampEnabled}) {
    return FileLoggerState(
      isLogging: isLogging ?? this.isLogging,
      timestampEnabled: timestampEnabled ?? this.timestampEnabled,
    );
  }
}

/// Global provider for [FileLoggerNotifier].
final fileLoggerNotifierProvider =
    NotifierProvider<FileLoggerNotifier, FileLoggerState>(
      FileLoggerNotifier.new,
    );

/// Streams terminal output into timestamped log files.
class FileLoggerNotifier extends Notifier<FileLoggerState> {
  IOSink? _sink;
  String _buffer = '';
  bool _needsTimestamp = true;

  static final _ansiEscape = RegExp(r'\x1b\[[0-?]*[ -/]*[@-~]');
  static final _controlChars = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

  @override
  FileLoggerState build() {
    ref.onDispose(_closeSink);
    return const FileLoggerState();
  }

  /// Prompts the user to select a folder and starts logging terminal traffic.
  Future<bool> startLogging() async {
    final dir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select folder to save log',
      initialDirectory: _desktopPath(),
    );
    if (dir == null) return false;

    final now = DateTime.now();
    final ts =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final file = File(p.join(dir, 'term_$ts.txt'));
    _sink = file.openWrite(mode: FileMode.append);
    _buffer = '';
    _needsTimestamp = true;
    state = state.copyWith(isLogging: true);
    return true;
  }

  /// Stops logging and closes the active file sink.
  Future<void> stopLogging() async {
    if (_sink == null) return;
    if (_buffer.isNotEmpty) {
      final sanitized = _sanitize(_buffer);
      _buffer = '';
      if (sanitized.isNotEmpty) _write(sanitized);
    }
    await _closeSink();
    state = state.copyWith(isLogging: false);
  }

  Future<void> _closeSink() async {
    await _sink?.close();
    _sink = null;
  }

  String? _desktopPath() {
    final home = Platform.isWindows
        ? Platform.environment['USERPROFILE']
        : Platform.environment['HOME'];
    if (home == null) return null;
    final desktop = Directory(p.join(home, 'Desktop'));
    return desktop.existsSync() ? desktop.path : home;
  }

  /// Toggles timestamp prepending on each log line.
  void setTimestamp(bool enabled) {
    state = state.copyWith(timestampEnabled: enabled);
  }

  /// Writes output data into the log file after stripping escape characters.
  void log(String data) {
    if (_sink == null) return;
    _buffer += data;

    // Strip complete ANSI sequences.
    _buffer = _buffer.replaceAll(_ansiEscape, '');

    // Hold back incomplete escape sequences at the tail.
    final escIdx = _buffer.lastIndexOf('\x1b');
    String safe = _buffer;

    if (escIdx != -1) {
      if (_buffer.length - escIdx > 32) {
        safe = _buffer;
        _buffer = '';
      } else {
        safe = _buffer.substring(0, escIdx);
        _buffer = _buffer.substring(escIdx);
      }
    } else {
      _buffer = '';
    }

    if (safe.isNotEmpty) {
      safe = _sanitize(safe);
      if (safe.isNotEmpty) _write(safe);
    }
  }

  String _sanitize(String data) => data
      .replaceAll('\r', '')
      .replaceAll(_controlChars, '')
      .replaceAll('', '');

  void _write(String data) {
    if (!state.timestampEnabled) {
      _sink!.write(data);
      if (data.endsWith('\n')) {
        _needsTimestamp = true;
      } else if (data.isNotEmpty) {
        _needsTimestamp = false;
      }
      return;
    }

    final prefix = '[${DateTime.now().toLocal()}] ';
    var out = data;
    if (_needsTimestamp) {
      out = '$prefix$out';
      _needsTimestamp = false;
    }
    out = out.replaceAll('\n', '\n$prefix');
    if (data.endsWith('\n')) {
      if (out.endsWith(prefix)) {
        out = out.substring(0, out.length - prefix.length);
      }
      _needsTimestamp = true;
    }
    _sink!.write(out);
  }
}
