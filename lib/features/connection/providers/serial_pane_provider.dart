import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:xterm/xterm.dart';

import '../../../services/file_logger_service.dart';
import '../../terminal/models/terminal_tab.dart';
import '../../terminal/providers/terminal_instances.dart';
import '../models/serial_config.dart';
import 'board_console.dart';

/// Standard commonly used baud rates for serial communication.
const standardBaudRates = [
  9600,
  19200,
  38400,
  57600,
  115200,
  230400,
  460800,
  921600,
  1500000,
];

/// Global provider for saved custom baud rates list.
final customBaudRatesProvider =
    NotifierProvider<CustomBaudRatesNotifier, List<int>>(
      CustomBaudRatesNotifier.new,
    );

/// Manages and persists user-defined custom baud rates in Hive.
class CustomBaudRatesNotifier extends Notifier<List<int>> {
  static const _boxName = 'app_settings';
  static const _key = 'custom_baud_rates';

  @override
  List<int> build() {
    final list = <int>{};
    if (Hive.isBoxOpen(_boxName)) {
      final box = Hive.box<String>(_boxName);
      final raw = box.get(_key);
      if (raw != null && raw.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
          for (final item in decoded) {
            final parsed = int.tryParse(item.toString());
            if (parsed != null &&
                parsed > 0 &&
                !standardBaudRates.contains(parsed)) {
              list.add(parsed);
            }
          }
        } catch (_) {}
      }
      final savedBaud = SerialPaneNotifier.getPersistedBaudRate();
      if (!standardBaudRates.contains(savedBaud)) {
        list.add(savedBaud);
      }
    }
    return list.toList()..sort();
  }

  /// Adds a custom baud rate to storage and state.
  void add(int baud) {
    if (standardBaudRates.contains(baud) || state.contains(baud)) return;
    final updated = [...state, baud]..sort();
    state = updated;
    _save(updated);
  }

  /// Removes a custom baud rate from storage and state.
  void remove(int baud) {
    if (!state.contains(baud)) return;
    final updated = state.where((b) => b != baud).toList();
    state = updated;
    _save(updated);
  }

  void _save(List<int> list) {
    if (Hive.isBoxOpen(_boxName)) {
      Hive.box<String>(_boxName).put(_key, jsonEncode(list));
    }
  }
}

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
final serialActiveTabIdProvider =
    NotifierProvider<SerialActiveTabIdNotifier, String?>(
      SerialActiveTabIdNotifier.new,
    );

/// Notifier tracking and persisting the explicitly selected SERIAL tab ID.
class SerialActiveTabIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    listenSelf(
      (prev, next) => TerminalLayoutPersistence.saveSerialActiveTabId(next),
    );
    return TerminalLayoutPersistence.readSerialActiveTabId();
  }

  @override
  String? get state => super.state;

  @override
  set state(String? value) => super.state = value;
}

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
  static const _boxName = 'app_settings';
  static const _baudRateKey = 'serial_baud_rate';
  static const _paneConfigPrefix = 'serial_pane_config_';
  static const int defaultBaudRate = 115200;

  _SerialBackend? _backend;
  Timer? _readTimer;
  bool _reading = false;
  final ConsoleCommandSession _cmd = ConsoleCommandSession();

  bool get isConnected => state.isConnected;

  /// Retrieves the saved baud rate from Hive, falling back to [defaultBaudRate].
  static int getPersistedBaudRate() {
    if (Hive.isBoxOpen(_boxName)) {
      final box = Hive.box<String>(_boxName);
      final raw = box.get(_baudRateKey);
      if (raw != null) {
        final parsed = int.tryParse(raw);
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    return defaultBaudRate;
  }

  /// Deletes persisted serial configuration for a closed tab [id].
  static void deletePersistedConfig(String id) {
    if (Hive.isBoxOpen(_boxName)) {
      Hive.box<String>(_boxName).delete('$_paneConfigPrefix$id');
    }
  }

  @override
  SerialPaneState build(String arg) {
    ref.onDispose(_cleanup);
    return SerialPaneState(config: _loadPaneConfig(arg));
  }

  SerialConfig _loadPaneConfig(String tabId) {
    final fallbackBaud = getPersistedBaudRate();
    if (!Hive.isBoxOpen(_boxName)) {
      return SerialConfig(baudRate: fallbackBaud);
    }
    final raw = Hive.box<String>(_boxName).get('$_paneConfigPrefix$tabId');
    if (raw == null || raw.isEmpty) {
      return SerialConfig(baudRate: fallbackBaud);
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final loaded = SerialConfig.fromJson(map);
      return loaded.copyWith(
        baudRate: loaded.baudRate > 0 ? loaded.baudRate : fallbackBaud,
      );
    } catch (_) {
      return SerialConfig(baudRate: fallbackBaud);
    }
  }

  void _savePaneConfig(SerialConfig cfg) {
    if (!Hive.isBoxOpen(_boxName)) return;
    Hive.box<String>(_boxName).put(
      '$_paneConfigPrefix$arg',
      jsonEncode(cfg.toJson()),
    );
  }

  /// Writes raw string data to the open serial port.
  void send(String data) {
    final backend = _backend;
    if (backend == null) return;
    try {
      backend.write(Uint8List.fromList(utf8.encode(data)));
    } catch (_) {}
  }

  /// Runs [command] on the serial console and returns its captured stdout.
  Future<String> runCommand(
    String command, {
    Duration timeout = const Duration(seconds: 4),
  }) {
    if (_backend == null) {
      return Future.error(StateError('Serial port is not connected'));
    }
    return _cmd.run(
      (data) => _backend?.write(Uint8List.fromList(utf8.encode(data))),
      command,
      timeout: timeout,
    );
  }

  void setPort(String port) {
    final updated = state.config.copyWith(port: port);
    state = state.copyWith(config: updated);
    _savePaneConfig(updated);
  }

  void setBaudRate(int baud) {
    final updated = state.config.copyWith(baudRate: baud);
    state = state.copyWith(config: updated);
    _saveBaudRate(baud);
    _savePaneConfig(updated);
  }

  static void _saveBaudRate(int baud) {
    if (Hive.isBoxOpen(_boxName)) {
      Hive.box<String>(_boxName).put(_baudRateKey, baud.toString());
    }
  }

  void setDataBits(int dataBits) {
    final updated = state.config.copyWith(dataBits: dataBits);
    state = state.copyWith(config: updated);
    _savePaneConfig(updated);
  }

  void setParity(SerialParity parity) {
    final updated = state.config.copyWith(parity: parity);
    state = state.copyWith(config: updated);
    _savePaneConfig(updated);
  }

  void setStopBits(SerialStopBits stopBits) {
    final updated = state.config.copyWith(stopBits: stopBits);
    state = state.copyWith(config: updated);
    _savePaneConfig(updated);
  }

  void setFlowControl(SerialFlowControl flowControl) {
    final updated = state.config.copyWith(flowControl: flowControl);
    state = state.copyWith(config: updated);
    _savePaneConfig(updated);
  }

  void setEncoding(SerialEncoding enc) {
    final updated = state.config.copyWith(encoding: enc);
    state = state.copyWith(config: updated);
    _savePaneConfig(updated);
  }

  void setNewLine(NewLine nl) {
    final updated = state.config.copyWith(newLine: nl);
    state = state.copyWith(config: updated);
    _savePaneConfig(updated);
  }

  /// Opens the serial port and initiates the periodic non-blocking read loop.
  Future<void> connect() async {
    final cfg = state.config;
    if (cfg.port.isEmpty ||
        state.isConnected ||
        state.status == SerialStatus.connecting) {
      return;
    }
    _cleanup();
    state = state.copyWith(status: SerialStatus.connecting, error: null);

    try {
      final backend = Platform.isWindows
          ? _Win32SerialBackend(cfg, onAsyncError: _handleFatalError)
          : _LibSerialPortBackend(cfg);
      backend.open();
      _backend = backend;

      _bindTerminalOutput();
      _readTimer = Timer.periodic(
        const Duration(milliseconds: 10),
        (_) => _pollRead(),
      );

      state = state.copyWith(status: SerialStatus.connected, error: null);
    } catch (e) {
      _cleanup();
      _terminal()?.write('\r\n[Serial error: $e]\r\n');
      state = state.copyWith(status: SerialStatus.disconnected, error: '$e');
    }
  }

  void _bindTerminalOutput() {
    final terminal = _terminal();
    if (terminal == null) return;
    terminal.onOutput = (data) {
      final nl = state.config.newLine;
      final out = nl == NewLine.none ? data : data.replaceAll('\r', nl.suffix);
      try {
        _backend?.write(Uint8List.fromList(utf8.encode(out)));
      } catch (e) {
        _handleFatalError(e);
      }
    };
  }

  void _pollRead() {
    if (_reading) return;
    final backend = _backend;
    if (backend == null) return;
    _reading = true;
    try {
      // Ensure terminal onOutput handler remains bound to the current tab's terminal.
      final terminal = _terminal();
      if (terminal != null && terminal.onOutput == null) {
        _bindTerminalOutput();
      }

      // Drain up to 4 chunks (64 KB) per 10 ms tick to sustain high baud rates.
      for (var i = 0; i < 4; i++) {
        final data = backend.readAvailable();
        if (data == null || data.isEmpty) break;
        final text = _decode(data, state.config.encoding);
        _cmd.feed(text);
        if (!ref.read(terminalPausedProvider)) {
          terminal?.write(text);
          ref.read(fileLoggerNotifierProvider.notifier).log(text);
        }
      }
    } catch (e) {
      _handleFatalError(e);
    } finally {
      _reading = false;
    }
  }

  void _handleFatalError(Object e) {
    _cleanup();
    _terminal()?.write('\r\n[Serial disconnected: $e]\r\n');
    state = state.copyWith(status: SerialStatus.disconnected, error: '$e');
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
    _readTimer?.cancel();
    _readTimer = null;
    _reading = false;
    _backend?.close();
    _backend = null;
  }
}

abstract class _SerialBackend {
  void open();
  Uint8List? readAvailable();
  void write(Uint8List data);
  void close();
}

/// Cross-platform fallback serial backend using `flutter_libserialport` without
/// its broken `SerialPortReader` isolate.
class _LibSerialPortBackend implements _SerialBackend {
  _LibSerialPortBackend(this.config);

  final SerialConfig config;
  SerialPort? _port;

  String get portName => config.port;

  @override
  void open() {
    final port = SerialPort(portName);
    if (!port.openReadWrite()) {
      final msg = SerialPort.lastError?.message ?? 'Failed to open $portName';
      port.dispose();
      throw SerialPortError(msg);
    }
    try {
      final parity = switch (config.parity) {
        SerialParity.none => SerialPortParity.none,
        SerialParity.odd => SerialPortParity.odd,
        SerialParity.even => SerialPortParity.even,
        SerialParity.mark => SerialPortParity.mark,
        SerialParity.space => SerialPortParity.space,
      };
      final flow = switch (config.flowControl) {
        SerialFlowControl.none => SerialPortFlowControl.none,
        SerialFlowControl.rtsCts => SerialPortFlowControl.rtsCts,
        SerialFlowControl.xonXoff => SerialPortFlowControl.xonXoff,
      };
      final cfg = SerialPortConfig()
        ..baudRate = config.baudRate
        ..bits = config.dataBits
        ..parity = parity
        ..stopBits = config.stopBits.libserialportValue
        ..setFlowControl(flow)
        ..dtr = SerialPortDtr.on
        ..rts = SerialPortRts.on;
      port.config = cfg;
      port.flush(SerialPortBuffer.both);
      _port = port;
    } catch (e) {
      port.close();
      port.dispose();
      rethrow;
    }
  }

  @override
  Uint8List? readAvailable() {
    final port = _port;
    if (port == null) return null;
    final available = port.bytesAvailable;
    if (available < 0) {
      throw SerialPortError(
        SerialPort.lastError?.message ?? 'Serial port read error',
      );
    }
    if (available == 0) return null;
    final toRead = available > 16384 ? 16384 : available;
    return port.read(toRead, timeout: 20);
  }

  @override
  void write(Uint8List data) {
    final port = _port;
    if (port == null || data.isEmpty) return;
    port.write(data, timeout: 200);
  }

  @override
  void close() {
    final port = _port;
    _port = null;
    if (port != null) {
      try {
        port.close();
      } catch (_) {}
      try {
        port.dispose();
      } catch (_) {}
    }
  }
}

/// Direct Win32 serial backend (`kernel32.dll`).
///
/// Bypasses `libserialport` on Windows to avoid:
/// 1. `get_port_details` opening/closing the COM port and sending raw USB hub
///    descriptor control transfers (`IOCTL_USB_GET_DESCRIPTOR_FROM_NODE_CONNECTION`)
///    that disrupt sibling UART interfaces on composite USB devices (such as
///    multi-port SEGGER J-Link CDC UART bridges).
/// 2. `WaitCommEvent` manual-reset event spin-loops (100% CPU) and unhandled
///    isolate crashes in `SerialPortReader`.
/// 3. Missing `DTR`/`RTS` assertion (`DTR_CONTROL_ENABLE` / `RTS_CONTROL_ENABLE`
///    and `SETDTR`/`SETRTS`), which USB CDC-ACM bridges require before
///    forwarding TX/RX traffic.
/// 4. Dropped writes in `sp_nonblocking_write` when an overlapped write is
///    still pending.
class _Win32SerialBackend implements _SerialBackend {
  _Win32SerialBackend(this.config, {this.onAsyncError});

  final SerialConfig config;
  final void Function(Object error)? onAsyncError;

  String get portName => config.port;
  int get baudRate => config.baudRate;

  static const int _invalidHandleValue = -1;
  static const int _genericRead = 0x80000000;
  static const int _genericWrite = 0x40000000;
  static const int _openExisting = 3;
  static const int _fileAttributeNormal = 0x00000080;
  static const int _fileFlagOverlapped = 0x40000000;
  static const int _lptrZeroInit = 0x0040; // LMEM_FIXED | LMEM_ZEROINIT
  static const int _errorIoPending = 997;
  static const int _waitObject0 = 0x00000000;
  static const int _purgeFlags = 0x000F; // TXABORT|RXABORT|TXCLEAR|RXCLEAR
  static const int _setRts = 3;
  static const int _setDtr = 5;
  static const int _ioBufferSize = 16384;

  static final ffi.DynamicLibrary _kernel32 = ffi.DynamicLibrary.open(
    'kernel32.dll',
  );

  static final _localAlloc = _kernel32
      .lookupFunction<
        ffi.Pointer<ffi.Void> Function(ffi.Uint32 uFlags, ffi.IntPtr uBytes),
        ffi.Pointer<ffi.Void> Function(int uFlags, int uBytes)
      >('LocalAlloc');

  static final _localFree = _kernel32
      .lookupFunction<
        ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void> hMem),
        ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void> hMem)
      >('LocalFree');

  static final _createFileW = _kernel32
      .lookupFunction<
        ffi.IntPtr Function(
          ffi.Pointer<ffi.Uint16> lpFileName,
          ffi.Uint32 dwDesiredAccess,
          ffi.Uint32 dwShareMode,
          ffi.Pointer<ffi.Void> lpSecurityAttributes,
          ffi.Uint32 dwCreationDisposition,
          ffi.Uint32 dwFlagsAndAttributes,
          ffi.IntPtr hTemplateFile,
        ),
        int Function(
          ffi.Pointer<ffi.Uint16> lpFileName,
          int dwDesiredAccess,
          int dwShareMode,
          ffi.Pointer<ffi.Void> lpSecurityAttributes,
          int dwCreationDisposition,
          int dwFlagsAndAttributes,
          int hTemplateFile,
        )
      >('CreateFileW');

  static final _closeHandle = _kernel32
      .lookupFunction<
        ffi.Int32 Function(ffi.IntPtr hObject),
        int Function(int hObject)
      >('CloseHandle');

  static final _getLastError = _kernel32
      .lookupFunction<ffi.Uint32 Function(), int Function()>('GetLastError');

  static final _setupComm = _kernel32
      .lookupFunction<
        ffi.Int32 Function(
          ffi.IntPtr hFile,
          ffi.Uint32 dwInQueue,
          ffi.Uint32 dwOutQueue,
        ),
        int Function(int hFile, int dwInQueue, int dwOutQueue)
      >('SetupComm');

  static final _getCommState = _kernel32
      .lookupFunction<
        ffi.Int32 Function(ffi.IntPtr hFile, ffi.Pointer<ffi.Uint8> lpDCB),
        int Function(int hFile, ffi.Pointer<ffi.Uint8> lpDCB)
      >('GetCommState');

  static final _setCommState = _kernel32
      .lookupFunction<
        ffi.Int32 Function(ffi.IntPtr hFile, ffi.Pointer<ffi.Uint8> lpDCB),
        int Function(int hFile, ffi.Pointer<ffi.Uint8> lpDCB)
      >('SetCommState');

  static final _setCommTimeouts = _kernel32
      .lookupFunction<
        ffi.Int32 Function(
          ffi.IntPtr hFile,
          ffi.Pointer<ffi.Uint32> lpCommTimeouts,
        ),
        int Function(int hFile, ffi.Pointer<ffi.Uint32> lpCommTimeouts)
      >('SetCommTimeouts');

  static final _escapeCommFunction = _kernel32
      .lookupFunction<
        ffi.Int32 Function(ffi.IntPtr hFile, ffi.Uint32 dwFunc),
        int Function(int hFile, int dwFunc)
      >('EscapeCommFunction');

  static final _purgeComm = _kernel32
      .lookupFunction<
        ffi.Int32 Function(ffi.IntPtr hFile, ffi.Uint32 dwFlags),
        int Function(int hFile, int dwFlags)
      >('PurgeComm');

  static final _clearCommError = _kernel32
      .lookupFunction<
        ffi.Int32 Function(
          ffi.IntPtr hFile,
          ffi.Pointer<ffi.Uint32> lpErrors,
          ffi.Pointer<ffi.Uint32> lpStat,
        ),
        int Function(
          int hFile,
          ffi.Pointer<ffi.Uint32> lpErrors,
          ffi.Pointer<ffi.Uint32> lpStat,
        )
      >('ClearCommError');

  static final _readFile = _kernel32
      .lookupFunction<
        ffi.Int32 Function(
          ffi.IntPtr hFile,
          ffi.Pointer<ffi.Uint8> lpBuffer,
          ffi.Uint32 nNumberOfBytesToRead,
          ffi.Pointer<ffi.Uint32> lpNumberOfBytesRead,
          ffi.Pointer<ffi.Uint8> lpOverlapped,
        ),
        int Function(
          int hFile,
          ffi.Pointer<ffi.Uint8> lpBuffer,
          int nNumberOfBytesToRead,
          ffi.Pointer<ffi.Uint32> lpNumberOfBytesRead,
          ffi.Pointer<ffi.Uint8> lpOverlapped,
        )
      >('ReadFile');

  static final _writeFile = _kernel32
      .lookupFunction<
        ffi.Int32 Function(
          ffi.IntPtr hFile,
          ffi.Pointer<ffi.Uint8> lpBuffer,
          ffi.Uint32 nNumberOfBytesToWrite,
          ffi.Pointer<ffi.Uint32> lpNumberOfBytesWritten,
          ffi.Pointer<ffi.Uint8> lpOverlapped,
        ),
        int Function(
          int hFile,
          ffi.Pointer<ffi.Uint8> lpBuffer,
          int nNumberOfBytesToWrite,
          ffi.Pointer<ffi.Uint32> lpNumberOfBytesWritten,
          ffi.Pointer<ffi.Uint8> lpOverlapped,
        )
      >('WriteFile');

  static final _createEventW = _kernel32
      .lookupFunction<
        ffi.IntPtr Function(
          ffi.Pointer<ffi.Void> lpEventAttributes,
          ffi.Int32 bManualReset,
          ffi.Int32 bInitialState,
          ffi.Pointer<ffi.Uint16> lpName,
        ),
        int Function(
          ffi.Pointer<ffi.Void> lpEventAttributes,
          int bManualReset,
          int bInitialState,
          ffi.Pointer<ffi.Uint16> lpName,
        )
      >('CreateEventW');

  static final _resetEvent = _kernel32
      .lookupFunction<
        ffi.Int32 Function(ffi.IntPtr hEvent),
        int Function(int hEvent)
      >('ResetEvent');

  static final _waitForSingleObject = _kernel32
      .lookupFunction<
        ffi.Uint32 Function(ffi.IntPtr hHandle, ffi.Uint32 dwMilliseconds),
        int Function(int hHandle, int dwMilliseconds)
      >('WaitForSingleObject');

  static final _getOverlappedResult = _kernel32
      .lookupFunction<
        ffi.Int32 Function(
          ffi.IntPtr hFile,
          ffi.Pointer<ffi.Uint8> lpOverlapped,
          ffi.Pointer<ffi.Uint32> lpNumberOfBytesTransferred,
          ffi.Int32 bWait,
        ),
        int Function(
          int hFile,
          ffi.Pointer<ffi.Uint8> lpOverlapped,
          ffi.Pointer<ffi.Uint32> lpNumberOfBytesTransferred,
          int bWait,
        )
      >('GetOverlappedResult');

  static final _cancelIoEx = _kernel32
      .lookupFunction<
        ffi.Int32 Function(
          ffi.IntPtr hFile,
          ffi.Pointer<ffi.Uint8> lpOverlapped,
        ),
        int Function(int hFile, ffi.Pointer<ffi.Uint8> lpOverlapped)
      >('CancelIoEx');

  int _hPort = _invalidHandleValue;
  int _readEvent = 0;
  int _writeEvent = 0;
  ffi.Pointer<ffi.Uint8> _readOvl = ffi.nullptr;
  ffi.Pointer<ffi.Uint8> _writeOvl = ffi.nullptr;
  ffi.Pointer<ffi.Uint32> _errorsPtr = ffi.nullptr;
  ffi.Pointer<ffi.Uint32> _comstatPtr = ffi.nullptr;
  ffi.Pointer<ffi.Uint32> _bytesTransferredPtr = ffi.nullptr;
  ffi.Pointer<ffi.Uint32> _writeBytesTransferredPtr = ffi.nullptr;
  ffi.Pointer<ffi.Uint8> _readBuf = ffi.nullptr;
  ffi.Pointer<ffi.Uint8> _writeBuf = ffi.nullptr;
  final List<Uint8List> _writeQueue = [];
  bool _drainingWrites = false;

  static int get _overlappedSize => ffi.sizeOf<ffi.IntPtr>() == 8 ? 32 : 20;
  static int get _overlappedEventOffset =>
      ffi.sizeOf<ffi.IntPtr>() == 8 ? 24 : 16;

  static bool _ffiWarmedUp = false;

  /// Eagerly resolves all lazy `static final` FFI function pointers before I/O.
  ///
  /// Without this, the first access to `_getLastError` after `_writeFile`
  /// returns `FALSE` (`ERROR_IO_PENDING`) triggers `DynamicLibrary.lookupFunction`
  /// (`GetProcAddress`) inside the Dart VM, which overwrites the Win32 thread's
  /// `LastError` from `997` (`ERROR_IO_PENDING`) to `0` (`ERROR_SUCCESS`).
  static void _warmUpFfi() {
    if (_ffiWarmedUp) return;
    _ffiWarmedUp = true;
    _localAlloc;
    _localFree;
    _createFileW;
    _closeHandle;
    _getLastError();
    _setupComm;
    _getCommState;
    _setCommState;
    _setCommTimeouts;
    _escapeCommFunction;
    _purgeComm;
    _clearCommError;
    _readFile;
    _writeFile;
    _createEventW;
    _resetEvent;
    _waitForSingleObject;
    _getOverlappedResult;
    _cancelIoEx;
  }

  @override
  void open() {
    _warmUpFfi();
    final normalized = portName.startsWith(r'\\.\')
        ? portName
        : '\\\\.\\$portName';
    final units = normalized.codeUnits;
    final pathPtr = _localAlloc(
      _lptrZeroInit,
      (units.length + 1) * 2,
    ).cast<ffi.Uint16>();
    try {
      final pathList = pathPtr.asTypedList(units.length + 1);
      for (var i = 0; i < units.length; i++) {
        pathList[i] = units[i];
      }
      pathList[units.length] = 0;

      _hPort = _createFileW(
        pathPtr,
        _genericRead | _genericWrite,
        0,
        ffi.nullptr,
        _openExisting,
        _fileAttributeNormal | _fileFlagOverlapped,
        0,
      );
    } finally {
      _localFree(pathPtr.cast());
    }

    if (_hPort == _invalidHandleValue || _hPort == 0) {
      final err = _getLastError();
      _hPort = _invalidHandleValue;
      throw StateError('Failed to open $portName (Win32 error $err)');
    }

    try {
      _setupComm(_hPort, 65536, 65536);

      // Configure DCB (28 bytes)
      final dcbPtr = _localAlloc(_lptrZeroInit, 32).cast<ffi.Uint8>();
      try {
        final dcbData = dcbPtr.asTypedList(28).buffer.asByteData();
        dcbData.setUint32(0, 28, Endian.little); // DCBlength = 28
        if (_getCommState(_hPort, dcbPtr) == 0) {
          throw StateError(
            'GetCommState failed on $portName (Win32 error ${_getLastError()})',
          );
        }

        dcbData.setUint32(4, baudRate, Endian.little); // BaudRate

        // DCB bitfield flags at offset 8:
        // Enable fBinary (0x0001), DTR_CONTROL_ENABLE (0x0010), and configured flow control.
        var flags = dcbData.getUint32(8, Endian.little);
        const clearMask =
            0x00000002 | // fParity
            0x00000004 | // fOutxCtsFlow
            0x00000008 | // fOutxDsrFlow
            0x00000030 | // fDtrControl (2 bits)
            0x00000040 | // fDsrSensitivity
            0x00000100 | // fOutX
            0x00000200 | // fInX
            0x00000400 | // fErrorChar
            0x00000800 | // fNull
            0x00003000 | // fRtsControl (2 bits)
            0x00004000; // fAbortOnError
        var setMask = 0x00000001 | 0x00000010; // fBinary | DTR_CONTROL_ENABLE
        if (config.parity != SerialParity.none) {
          setMask |= 0x00000002; // fParity
        }
        switch (config.flowControl) {
          case SerialFlowControl.none:
            setMask |= 0x00001000; // RTS_CONTROL_ENABLE
          case SerialFlowControl.rtsCts:
            setMask |= 0x00000004 | 0x00002000; // fOutxCtsFlow | RTS_CONTROL_HANDSHAKE
          case SerialFlowControl.xonXoff:
            setMask |= 0x00001000 | 0x00000100 | 0x00000200; // RTS_ENABLE | fOutX | fInX
        }
        flags = (flags & ~clearMask) | setMask;
        dcbData.setUint32(8, flags, Endian.little);

        dcbData.setUint8(18, config.dataBits); // ByteSize
        dcbData.setUint8(19, config.parity.win32Value); // Parity
        dcbData.setUint8(20, config.stopBits.win32Value); // StopBits

        if (_setCommState(_hPort, dcbPtr) == 0) {
          throw StateError(
            'SetCommState failed on $portName (Win32 error ${_getLastError()})',
          );
        }
      } finally {
        _localFree(dcbPtr.cast());
      }

      // Explicitly assert DTR and RTS control signals for USB CDC-ACM bridges (e.g., SEGGER J-Link VCOM).
      _escapeCommFunction(_hPort, _setDtr);
      _escapeCommFunction(_hPort, _setRts);

      // Configure COMMTIMEOUTS (20 bytes): immediate non-blocking reads, 200 ms write timeout.
      final timeoutsPtr = _localAlloc(_lptrZeroInit, 20).cast<ffi.Uint32>();
      try {
        final timeouts = timeoutsPtr.asTypedList(5);
        timeouts[0] = 0xFFFFFFFF; // ReadIntervalTimeout = MAXDWORD
        timeouts[1] = 0; // ReadTotalTimeoutMultiplier = 0
        timeouts[2] = 0; // ReadTotalTimeoutConstant = 0
        timeouts[3] = 0; // WriteTotalTimeoutMultiplier = 0
        timeouts[4] = 200; // WriteTotalTimeoutConstant = 200 ms
        if (_setCommTimeouts(_hPort, timeoutsPtr) == 0) {
          throw StateError(
            'SetCommTimeouts failed on $portName (Win32 error ${_getLastError()})',
          );
        }
      } finally {
        _localFree(timeoutsPtr.cast());
      }

      _readEvent = _createEventW(ffi.nullptr, 1, 0, ffi.nullptr);
      _writeEvent = _createEventW(ffi.nullptr, 1, 0, ffi.nullptr);
      _readOvl = _localAlloc(_lptrZeroInit, _overlappedSize).cast<ffi.Uint8>();
      _writeOvl = _localAlloc(_lptrZeroInit, _overlappedSize).cast<ffi.Uint8>();
      _errorsPtr = _localAlloc(_lptrZeroInit, 4).cast<ffi.Uint32>();
      _comstatPtr = _localAlloc(_lptrZeroInit, 12).cast<ffi.Uint32>();
      _bytesTransferredPtr = _localAlloc(_lptrZeroInit, 4).cast<ffi.Uint32>();
      _writeBytesTransferredPtr = _localAlloc(_lptrZeroInit, 4).cast<ffi.Uint32>();
      _readBuf = _localAlloc(_lptrZeroInit, _ioBufferSize).cast<ffi.Uint8>();
      _writeBuf = _localAlloc(_lptrZeroInit, _ioBufferSize).cast<ffi.Uint8>();

      _clearCommError(_hPort, _errorsPtr, _comstatPtr);
      _purgeComm(_hPort, _purgeFlags);
    } catch (_) {
      close();
      rethrow;
    }
  }

  void _prepareOverlapped(ffi.Pointer<ffi.Uint8> ovl, int hEvent) {
    final bytes = ovl.asTypedList(_overlappedSize);
    bytes.fillRange(0, _overlappedSize, 0);
    final bd = bytes.buffer.asByteData();
    if (ffi.sizeOf<ffi.IntPtr>() == 8) {
      bd.setInt64(_overlappedEventOffset, hEvent, Endian.little);
    } else {
      bd.setInt32(_overlappedEventOffset, hEvent, Endian.little);
    }
    _resetEvent(hEvent);
  }

  @override
  Uint8List? readAvailable() {
    if (_hPort == _invalidHandleValue) return null;
    if (_clearCommError(_hPort, _errorsPtr, _comstatPtr) == 0) {
      throw StateError(
        'Device disconnected on $portName (Win32 error ${_getLastError()})',
      );
    }

    // COMSTAT.cbInQue is at DWORD index 1 (byte offset 4).
    final cbInQue = _comstatPtr.asTypedList(3)[1];
    if (cbInQue == 0) return null;

    final toRead = cbInQue > _ioBufferSize ? _ioBufferSize : cbInQue;
    _prepareOverlapped(_readOvl, _readEvent);
    _bytesTransferredPtr.value = 0;

    final ok = _readFile(
      _hPort,
      _readBuf,
      toRead,
      _bytesTransferredPtr,
      _readOvl,
    );
    if (ok == 0) {
      final err = _getLastError();
      if (err == _errorIoPending || err == 0) {
        final waitRes = _waitForSingleObject(_readEvent, 50);
        if (waitRes != _waitObject0 ||
            _getOverlappedResult(_hPort, _readOvl, _bytesTransferredPtr, 0) ==
                0) {
          _cancelIoEx(_hPort, _readOvl);
          _getOverlappedResult(_hPort, _readOvl, _bytesTransferredPtr, 1);
          return null;
        }
      } else {
        throw StateError('ReadFile failed on $portName (Win32 error $err)');
      }
    }

    final bytesRead = _bytesTransferredPtr.value;
    if (bytesRead <= 0) return null;
    return Uint8List.fromList(_readBuf.asTypedList(bytesRead));
  }

  @override
  void write(Uint8List data) {
    if (_hPort == _invalidHandleValue || data.isEmpty) return;
    _writeQueue.add(Uint8List.fromList(data));
    if (!_drainingWrites) {
      unawaited(_drainWriteQueue());
    }
  }

  Future<void> _drainWriteQueue() async {
    if (_drainingWrites) return;
    _drainingWrites = true;
    try {
      while (_writeQueue.isNotEmpty && _hPort != _invalidHandleValue) {
        final data = _writeQueue.removeAt(0);
        var offset = 0;
        while (offset < data.length && _hPort != _invalidHandleValue) {
          final end = (offset + _ioBufferSize < data.length)
              ? offset + _ioBufferSize
              : data.length;
          final chunkLen = end - offset;
          _writeBuf.asTypedList(chunkLen).setRange(0, chunkLen, data, offset);

          _prepareOverlapped(_writeOvl, _writeEvent);
          _writeBytesTransferredPtr.value = 0;

          final ok = _writeFile(
            _hPort,
            _writeBuf,
            chunkLen,
            _writeBytesTransferredPtr,
            _writeOvl,
          );
          if (ok == 0) {
            final err = _getLastError();
            if (err == _errorIoPending || err == 0) {
              // Poll overlapped completion asynchronously so large writes do not block the UI thread.
              final deadline = DateTime.now().add(
                const Duration(milliseconds: 250),
              );
              var completed = false;
              while (_hPort != _invalidHandleValue) {
                if (_waitForSingleObject(_writeEvent, 0) == _waitObject0) {
                  if (_getOverlappedResult(
                        _hPort,
                        _writeOvl,
                        _writeBytesTransferredPtr,
                        0,
                      ) ==
                      0) {
                    final ovlErr = _getLastError();
                    throw StateError(
                      'WriteFile failed on $portName (Win32 error $ovlErr)',
                    );
                  }
                  completed = true;
                  break;
                }
                if (DateTime.now().isAfter(deadline)) break;
                await Future<void>.delayed(const Duration(milliseconds: 1));
              }
              if (!completed) {
                if (_hPort == _invalidHandleValue) return;
                _cancelIoEx(_hPort, _writeOvl);
                _getOverlappedResult(
                  _hPort,
                  _writeOvl,
                  _writeBytesTransferredPtr,
                  1,
                );
                throw TimeoutException('WriteFile timed out on $portName');
              }
            } else {
              throw StateError(
                'WriteFile failed on $portName (Win32 error $err)',
              );
            }
          }
          offset = end;
        }
      }
    } catch (e) {
      _writeQueue.clear();
      onAsyncError?.call(e);
    } finally {
      _drainingWrites = false;
    }
  }

  void _freePtr(ffi.Pointer<ffi.NativeType> ptr) {
    if (ptr != ffi.nullptr) {
      _localFree(ptr.cast());
    }
  }

  @override
  void close() {
    if (_hPort != _invalidHandleValue && _hPort != 0) {
      _cancelIoEx(_hPort, ffi.nullptr);
      _closeHandle(_hPort);
      _hPort = _invalidHandleValue;
    }
    if (_readEvent != 0) {
      _closeHandle(_readEvent);
      _readEvent = 0;
    }
    if (_writeEvent != 0) {
      _closeHandle(_writeEvent);
      _writeEvent = 0;
    }
    _freePtr(_readOvl);
    _readOvl = ffi.nullptr;
    _freePtr(_writeOvl);
    _writeOvl = ffi.nullptr;
    _freePtr(_errorsPtr);
    _errorsPtr = ffi.nullptr;
    _freePtr(_comstatPtr);
    _comstatPtr = ffi.nullptr;
    _freePtr(_bytesTransferredPtr);
    _bytesTransferredPtr = ffi.nullptr;
    _freePtr(_writeBytesTransferredPtr);
    _writeBytesTransferredPtr = ffi.nullptr;
    _writeQueue.clear();
    _freePtr(_readBuf);
    _readBuf = ffi.nullptr;
    _freePtr(_writeBuf);
    _writeBuf = ffi.nullptr;
  }
}
