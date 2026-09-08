import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Transport type backing a [BoardConsole].
enum ConsoleKind { pty, serial }

/// An interactive console interface for executing shell commands and capturing output.
abstract class BoardConsole {
  String get id;
  ConsoleKind get kind;
  bool get isConnected;

  /// Runs [command] and returns stdout with command echo and prompts stripped.
  Future<String> run(
    String command, {
    Duration timeout = const Duration(seconds: 4),
  });

  /// Writes raw [data] directly to the console (fire-and-forget).
  void send(String data);
}

/// Runs commands sequentially and captures output bounded by unique nonce markers.
class ConsoleCommandSession {
  static final RegExp _ansi = RegExp(r'\x1B\[[0-9;?]*[ -/]*[@-~]');

  Completer<String>? _completer;
  final StringBuffer _buf = StringBuffer();
  String _marker = '';
  String _sent = '';
  Timer? _timeout;

  bool get busy => _completer != null;

  /// Feeds decoded console output into the session parser.
  void feed(String text) {
    if (_completer == null) return;
    _buf.write(text);
    if (_buf.toString().contains(_marker)) _complete();
  }

  /// Sends a marked command to the underlying writer function and awaits the result.
  Future<String> run(
    void Function(String data) write,
    String command, {
    Duration timeout = const Duration(seconds: 4),
  }) {
    if (_completer != null) {
      return Future.error(StateError('Console is busy with another command'));
    }
    final nonce = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    _marker = 'SANCEND$nonce';
    _sent = '$command; echo SANC"END"$nonce';
    _buf.clear();
    final completer = _completer = Completer<String>();
    _timeout = Timer(timeout, () {
      if (_completer == completer && !completer.isCompleted) {
        _reset();
        completer.completeError(
          TimeoutException('Command timed out: $command'),
        );
      }
    });
    write('$_sent\r');
    return completer.future;
  }

  void _complete() {
    final completer = _completer!;
    final raw = _buf.toString();
    final result = _extract(raw);
    _reset();
    if (!completer.isCompleted) completer.complete(result);
  }

  String _extract(String raw) {
    final idx = raw.indexOf(_marker);
    final before = idx >= 0 ? raw.substring(0, idx) : raw;
    final out = <String>[];
    for (final rawLine in before.split('\n')) {
      final line = rawLine
          .replaceAll(_ansi, '')
          .replaceAll('\r', '')
          .trimRight();
      if (line.trim().isEmpty) continue;
      if (line.contains(_sent)) continue;
      out.add(line);
    }
    return out.join('\n').trim();
  }

  void _reset() {
    _timeout?.cancel();
    _timeout = null;
    _completer = null;
    _buf.clear();
  }
}

/// Console backed by a local [Pty] process.
class PtyConsole implements BoardConsole {
  PtyConsole({required this.id, required Pty pty}) : _pty = pty;

  @override
  final String id;
  final Pty _pty;
  final ConsoleCommandSession _session = ConsoleCommandSession();
  bool _alive = true;

  @override
  ConsoleKind get kind => ConsoleKind.pty;

  @override
  bool get isConnected => _alive;

  void feed(String text) => _session.feed(text);

  void markClosed() => _alive = false;

  @override
  Future<String> run(
    String command, {
    Duration timeout = const Duration(seconds: 4),
  }) {
    if (!_alive) {
      return Future.error(StateError('PTY process has terminated'));
    }
    return _session.run(
      (data) {
        try {
          _pty.write(Uint8List.fromList(data.codeUnits));
        } catch (_) {}
      },
      command,
      timeout: timeout,
    );
  }

  @override
  void send(String data) {
    if (!_alive) return;
    try {
      _pty.write(Uint8List.fromList(data.codeUnits));
    } catch (_) {}
  }
}

/// Registry tracking active board console instances.
class BoardConsoleRegistry {
  final Map<String, BoardConsole> _consoles = {};

  List<BoardConsole> get all => _consoles.values.toList();

  void register(BoardConsole console) => _consoles[console.id] = console;

  void unregister(String id) => _consoles.remove(id);

  BoardConsole? find(String id) => _consoles[id];
}

/// Global provider for [BoardConsoleRegistry].
final boardConsoleRegistryProvider = Provider<BoardConsoleRegistry>(
  (ref) => BoardConsoleRegistry(),
);
