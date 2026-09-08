import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../../../services/file_logger_service.dart';
import '../../terminal/models/terminal_tab.dart';
import '../../terminal/providers/terminal_instances.dart';
import '../models/serial_config.dart';
import 'board_console.dart';

/// Current connection lifecycle state of a serial port.
enum SerialStatus { disconnected, connecting, connected }

/// State object representing a serial pane's configuration and connection status.
class SerialPaneState {
  const SerialPaneState({
    this.config = const SerialConfig(),
    this.status = SerialStatus.disconnected,
    this.error,
  });

  final SerialConfig config;
  final SerialStatus status;
  final String? error;

  bool get isConnected => status == SerialStatus.connected;

  static const _unset = Object();

  SerialPaneState copyWith({
    SerialConfig? config,
    SerialStatus? status,
    Object? error = _unset,
  }) {
    return SerialPaneState(
      config: config ?? this.config,
      status: status ?? this.status,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}

/// Provider family supplying a [SerialPaneNotifier] per terminal tab ID.
final serialPaneNotifierProvider =
    NotifierProvider.family<SerialPaneNotifier, SerialPaneState, String>(
      SerialPaneNotifier.new,
    );

/// Explicitly selected active SERIAL tab id (set when a pane is tapped).
final serialActiveTabIdProvider = StateProvider<String?>((ref) => null);

/// Resolves the SERIAL tab that the connection bar currently controls.
final effectiveActiveSerialTabIdProvider = Provider<String?>((ref) {
  final serials = ref
      .watch(terminalTabsNotifierProvider)
      .where((t) => t.type == TerminalTabType.serial)
      .toList();
  if (serials.isEmpty) return null;

  final activeId = ref.watch(activeTabIdProvider);
  if (activeId != null && serials.any((t) => t.id == activeId)) return activeId;

  final selected = ref.watch(serialActiveTabIdProvider);
  if (selected != null && serials.any((t) => t.id == selected)) return selected;

  return serials.first.id;
});

/// Per-pane serial connection manager.
class SerialPaneNotifier extends FamilyNotifier<SerialPaneState, String> {
  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _sub;
  final ConsoleCommandSession _cmd = ConsoleCommandSession();

  bool get isConnected => state.isConnected;

  @override
  SerialPaneState build(String arg) {
    ref.onDispose(_cleanup);
    return const SerialPaneState();
  }

  /// Writes raw string data to the open serial port.
  void send(String data) {
    final port = _port;
    if (port == null) return;
    try {
      port.write(Uint8List.fromList(utf8.encode(data)));
    } catch (_) {}
  }

  /// Runs [command] on the serial console and returns its captured stdout.
  Future<String> runCommand(
    String command, {
    Duration timeout = const Duration(seconds: 4),
  }) {
    if (_port == null) {
      return Future.error(StateError('Serial port is not connected'));
    }
    return _cmd.run(
      (data) => _port?.write(Uint8List.fromList(utf8.encode(data))),
      command,
      timeout: timeout,
    );
  }

  void setPort(String port) =>
      state = state.copyWith(config: state.config.copyWith(port: port));

  void setBaudRate(int baud) =>
      state = state.copyWith(config: state.config.copyWith(baudRate: baud));

  void setEncoding(SerialEncoding enc) =>
      state = state.copyWith(config: state.config.copyWith(encoding: enc));

  void setNewLine(NewLine nl) =>
      state = state.copyWith(config: state.config.copyWith(newLine: nl));

  /// Opens the serial port and initiates the background read stream.
  Future<void> connect() async {
    final cfg = state.config;
    if (cfg.port.isEmpty || state.isConnected) return;
    state = state.copyWith(status: SerialStatus.connecting, error: null);

    try {
      final port = SerialPort(cfg.port);
      if (!port.openReadWrite()) {
        port.dispose();
        throw SerialPortError(
          SerialPort.lastError?.message ?? 'Failed to open port',
        );
      }
      port.config = SerialPortConfig()
        ..baudRate = cfg.baudRate
        ..bits = 8
        ..parity = SerialPortParity.none
        ..stopBits = 1
        ..setFlowControl(SerialPortFlowControl.none);
      _port = port;

      final terminal = _terminal();
      final reader = SerialPortReader(port);
      _reader = reader;
      _sub = reader.stream.listen(
        (data) {
          final text = _decode(data, state.config.encoding);
          _cmd.feed(text);
          if (!ref.read(terminalPausedProvider)) {
            terminal?.write(text);
            ref.read(fileLoggerNotifierProvider.notifier).log(text);
          }
        },
        onError: (Object e) {
          state = state.copyWith(
            status: SerialStatus.disconnected,
            error: '$e',
          );
          _cleanup();
        },
      );

      terminal?.onOutput = (data) {
        final nl = state.config.newLine;
        final out = nl == NewLine.none
            ? data
            : data.replaceAll('\r', nl.suffix);
        try {
          _port?.write(Uint8List.fromList(utf8.encode(out)));
        } catch (_) {}
      };

      state = state.copyWith(status: SerialStatus.connected, error: null);
    } catch (e) {
      _cleanup();
      state = state.copyWith(status: SerialStatus.disconnected, error: '$e');
    }
  }

  /// Closes the active serial port and clears error state.
  void disconnect() {
    _cleanup();
    state = state.copyWith(status: SerialStatus.disconnected, error: null);
  }

  Terminal? _terminal() {
    for (final t in ref.read(terminalTabsNotifierProvider)) {
      if (t.id == arg && t.type == TerminalTabType.serial) return t.terminal;
    }
    return null;
  }

  String _decode(Uint8List data, SerialEncoding enc) => switch (enc) {
    SerialEncoding.utf8 => const Utf8Decoder(
      allowMalformed: true,
    ).convert(data),
    SerialEncoding.latin1 => latin1.decode(data, allowInvalid: true),
    SerialEncoding.raw => String.fromCharCodes(data),
    SerialEncoding.hex =>
      '${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')} ',
  };

  void _cleanup() {
    _sub?.cancel();
    _sub = null;
    _reader?.close();
    _reader = null;
    _port?.close();
    _port?.dispose();
    _port = null;
  }
}
