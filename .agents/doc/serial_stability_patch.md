# Serial Multi-Port Stability Patch Guide

## Overview

When opening multiple COM ports simultaneously on Windows (such as 4 SEGGER J-Link CDC UART ports where `COM19` and `COM20` share a composite USB device), the 1st connected SERIAL terminal can stop receiving output and sending input until it is manually disconnected and reconnected.

This guide documents the root causes in `flutter_libserialport` (`libserialport`) and provides a drop-in patch for [`lib/features/connection/providers/serial_pane_provider.dart`](file:///D:/GIT/GitHub/term_template/lib/features/connection/providers/serial_pane_provider.dart) that can be applied to any project based on `term_template`.

## Root Causes

1. **Composite USB Hub Probing & Double-Open in `SerialPort(name)` (`windows.c`)**:
   - Constructing `SerialPort(portName)` invokes `get_port_details()` in `libserialport`, which opens `\\.\COMx` (`CreateFileA`) and immediately closes it (`CloseHandle`) before `openReadWrite()`. On USB CDC drivers (`JLinkCDC` / `usbser.sys`), closing the handle sends `SET_CONTROL_LINE_STATE(DTR=0, RTS=0)` right before the real open.
   - `get_port_details()` then opens the parent USB Host Controller and Hub and sends raw `IOCTL_USB_GET_DESCRIPTOR_FROM_NODE_CONNECTION` control transfers to the composite USB device. When connecting the 2nd, 3rd, and 4th COM ports, probing the shared composite USB device disrupts the already-open 1st COM port (`COM19`).

2. **`SerialPortReader` Isolate Silent Crash & 100% CPU Spin Loop (`serialport.c` / `reader.dart`)**:
   - **Silent Reader Isolate Crash**: `SerialPortReader` calls `sp_nonblocking_read`, which executes `ReadFile` followed immediately by `GetOverlappedResult(..., bWait: FALSE)`. If the USB driver returns `ERROR_IO_PENDING` while busy servicing other ports, `GetOverlappedResult` fails with `ERROR_IO_INCOMPLETE` (`996`), throwing an uncaught `SerialPortError` inside the reader isolate. The isolate terminates silently while the UI continues showing **Connected**.
   - **100% CPU Busy Loop**: `sp_open` creates `wait_ovl.hEvent` as a manual-reset event and starts `WaitCommEvent` before `SetCommState`. When an event completes with `cbInQue == 0` (e.g., `EV_ERR` during baud rate setup), `sp_wait` returns in `0 ms` without resetting the event and `restart_wait` is never called, causing the isolate thread to spin at 100% CPU calling `ClearCommError`.
   - **Zombie Isolate on Disconnect**: `SerialPortReader.close()` calls `_isolate?.kill()` with `Isolate.beforeNextEvent`, which cannot interrupt the synchronous `while (bytes >= 0)` loop in `_waitRead` before `_port.dispose()` frees native memory.

3. **Unset `DTR` / `RTS` Control Lines & Dropped Non-Blocking Writes**:
   - `SerialPortConfig()..setFlowControl(SerialPortFlowControl.none)` leaves `dtr = -1` and `rts = -1` on a newly allocated config struct, so `DTR_CONTROL_ENABLE` and `RTS_CONTROL_ENABLE` are never asserted in the Windows `DCB`.
   - `port.write(bytes)` defaults to `timeout = -1` (`sp_nonblocking_write`), which silently drops writes (`return 0`) whenever a previous overlapped write is still pending.

4. **First-Connection `WriteFile failed on COMx (Win32 error 0)` from Lazy FFI Initialization**:
   - In `_Win32SerialBackend`, Win32 FFI bindings (`_getLastError`, `_writeFile`, etc.) are declared as `static final` fields, which Dart initializes **lazily on first access**.
   - During `open()` and `readAvailable()`, all Win32 calls succeed synchronously, so `_getLastError` is never accessed.
   - On the very first `write()` call on the `FILE_FLAG_OVERLAPPED` handle, `WriteFile` queues the transfer asynchronously, sets the thread's Win32 `LastError` to `ERROR_IO_PENDING` (`997`), and returns `0` (`FALSE`).
   - Reading `_getLastError` for the first time triggers `_kernel32.lookupFunction('GetLastError')` inside the Dart VM, which calls Win32 `GetProcAddress` and allocates the FFI trampoline before invoking `GetLastError()`. Those internal Win32 calls succeed and overwrite the thread's `LastError` from `997` to `0` (`ERROR_SUCCESS`), causing `err == _errorIoPending` to fail with `Bad state: WriteFile failed on COMx (Win32 error 0)` on the 1st connection only.
   - Pre-resolving all FFI symbols in `_warmUpFfi()` at the start of `open()` and treating `err == _errorIoPending || err == 0` when `ReadFile` / `WriteFile` returns `0` (verifying completion via `WaitForSingleObject` + `GetOverlappedResult`) eliminates this failure.

## How to Patch Derived Apps

### Step 1: Update Imports in `serial_pane_provider.dart`

In `lib/features/connection/providers/serial_pane_provider.dart`, add `dart:ffi` and `dart:io`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
```

### Step 2: Replace `SerialPort` / `SerialPortReader` Fields in `SerialPaneNotifier`

Replace the `SerialPort? _port;`, `SerialPortReader? _reader;`, and `StreamSubscription<Uint8List>? _sub;` fields in `SerialPaneNotifier` with `_SerialBackend` and a periodic poll `Timer`:

```dart
  _SerialBackend? _backend;
  Timer? _readTimer;
  bool _reading = false;
  final ConsoleCommandSession _cmd = ConsoleCommandSession();
```

### Step 3: Update `send`, `runCommand`, `connect`, `disconnect`, and `_cleanup` in `SerialPaneNotifier`

Replace `send`, `runCommand`, `connect`, `disconnect`, and `_cleanup` in `SerialPaneNotifier` with the following implementation:

```dart
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
          ? _Win32SerialBackend(cfg.port, cfg.baudRate)
          : _LibSerialPortBackend(cfg.port, cfg.baudRate);
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
      final terminal = _terminal();
      if (terminal != null && terminal.onOutput == null) {
        _bindTerminalOutput();
      }

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

  void _cleanup() {
    _readTimer?.cancel();
    _readTimer = null;
    _reading = false;
    _backend?.close();
    _backend = null;
  }
```

### Step 4: Add `_SerialBackend`, `_LibSerialPortBackend`, and `_Win32SerialBackend`

Append the backend classes to the bottom of `lib/features/connection/providers/serial_pane_provider.dart` (see lines 420–1043 of [`serial_pane_provider.dart`](file:///D:/GIT/GitHub/term_template/lib/features/connection/providers/serial_pane_provider.dart#L420-L1043)):

```dart
abstract class _SerialBackend {
  void open();
  Uint8List? readAvailable();
  void write(Uint8List data);
  void close();
}

class _LibSerialPortBackend implements _SerialBackend {
  _LibSerialPortBackend(this.portName, this.baudRate);

  final String portName;
  final int baudRate;
  SerialPort? _port;

  @override
  void open() {
    final port = SerialPort(portName);
    if (!port.openReadWrite()) {
      final msg = SerialPort.lastError?.message ?? 'Failed to open $portName';
      port.dispose();
      throw SerialPortError(msg);
    }
    try {
      final cfg = SerialPortConfig()
        ..baudRate = baudRate
        ..bits = 8
        ..parity = SerialPortParity.none
        ..stopBits = 1
        ..setFlowControl(SerialPortFlowControl.none)
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

class _Win32SerialBackend implements _SerialBackend {
  _Win32SerialBackend(this.portName, this.baudRate);

  final String portName;
  final int baudRate;

  static const int _invalidHandleValue = -1;
  static const int _genericRead = 0x80000000;
  static const int _genericWrite = 0x40000000;
  static const int _openExisting = 3;
  static const int _fileAttributeNormal = 0x00000080;
  static const int _fileFlagOverlapped = 0x40000000;
  static const int _lptrZeroInit = 0x0040;
  static const int _errorIoPending = 997;
  static const int _waitObject0 = 0x00000000;
  static const int _purgeFlags = 0x000F;
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
  ffi.Pointer<ffi.Uint8> _readBuf = ffi.nullptr;
  ffi.Pointer<ffi.Uint8> _writeBuf = ffi.nullptr;

  static int get _overlappedSize => ffi.sizeOf<ffi.IntPtr>() == 8 ? 32 : 20;
  static int get _overlappedEventOffset =>
      ffi.sizeOf<ffi.IntPtr>() == 8 ? 24 : 16;

  static bool _ffiWarmedUp = false;

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

      final dcbPtr = _localAlloc(_lptrZeroInit, 32).cast<ffi.Uint8>();
      try {
        final dcbData = dcbPtr.asTypedList(28).buffer.asByteData();
        dcbData.setUint32(0, 28, Endian.little);
        if (_getCommState(_hPort, dcbPtr) == 0) {
          throw StateError(
            'GetCommState failed on $portName (Win32 error ${_getLastError()})',
          );
        }

        dcbData.setUint32(4, baudRate, Endian.little);

        var flags = dcbData.getUint32(8, Endian.little);
        const clearMask =
            0x00000002 |
            0x00000004 |
            0x00000008 |
            0x00000030 |
            0x00000040 |
            0x00000100 |
            0x00000200 |
            0x00000400 |
            0x00000800 |
            0x00003000 |
            0x00004000;
        flags = (flags & ~clearMask) | 0x00000001 | 0x00000010 | 0x00001000;
        dcbData.setUint32(8, flags, Endian.little);

        dcbData.setUint8(18, 8);
        dcbData.setUint8(19, 0);
        dcbData.setUint8(20, 0);

        if (_setCommState(_hPort, dcbPtr) == 0) {
          throw StateError(
            'SetCommState failed on $portName (Win32 error ${_getLastError()})',
          );
        }
      } finally {
        _localFree(dcbPtr.cast());
      }

      _escapeCommFunction(_hPort, _setDtr);
      _escapeCommFunction(_hPort, _setRts);

      final timeoutsPtr = _localAlloc(_lptrZeroInit, 20).cast<ffi.Uint32>();
      try {
        final timeouts = timeoutsPtr.asTypedList(5);
        timeouts[0] = 0xFFFFFFFF;
        timeouts[1] = 0;
        timeouts[2] = 0;
        timeouts[3] = 0;
        timeouts[4] = 200;
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
    var offset = 0;
    while (offset < data.length) {
      final end = (offset + _ioBufferSize < data.length)
          ? offset + _ioBufferSize
          : data.length;
      final chunkLen = end - offset;
      _writeBuf.asTypedList(chunkLen).setRange(0, chunkLen, data, offset);

      _prepareOverlapped(_writeOvl, _writeEvent);
      _bytesTransferredPtr.value = 0;

      final ok = _writeFile(
        _hPort,
        _writeBuf,
        chunkLen,
        _bytesTransferredPtr,
        _writeOvl,
      );
      if (ok == 0) {
        final err = _getLastError();
        if (err == _errorIoPending || err == 0) {
          final waitRes = _waitForSingleObject(_writeEvent, 250);
          if (waitRes == _waitObject0) {
            if (_getOverlappedResult(
                  _hPort,
                  _writeOvl,
                  _bytesTransferredPtr,
                  0,
                ) ==
                0) {
              final ovlErr = _getLastError();
              throw StateError(
                'WriteFile failed on $portName (Win32 error $ovlErr)',
              );
            }
          } else {
            _cancelIoEx(_hPort, _writeOvl);
            _getOverlappedResult(_hPort, _writeOvl, _bytesTransferredPtr, 1);
            break;
          }
        } else {
          throw StateError('WriteFile failed on $portName (Win32 error $err)');
        }
      }
      offset = end;
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
    _freePtr(_readBuf);
    _readBuf = ffi.nullptr;
    _freePtr(_writeBuf);
    _writeBuf = ffi.nullptr;
  }
}
```

## Verification

1. Run static analysis:

   ```powershell
   flutter analyze
   ```

2. Run the test suite:

   ```powershell
   flutter test
   ```
