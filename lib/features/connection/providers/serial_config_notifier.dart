import 'dart:io';
import 'dart:isolate';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether a port scan is currently in progress.
final serialScanLoadingProvider = StateProvider<bool>((ref) => false);

/// Provides the list of discovered serial port names.
final availablePortsNotifierProvider =
    NotifierProvider<AvailablePortsNotifier, List<String>>(
      AvailablePortsNotifier.new,
    );

/// Notifier that scans and lists active hardware serial ports.
class AvailablePortsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  /// Scans for available serial ports and updates state.
  Future<void> scan() async {
    final loadingNotifier = ref.read(serialScanLoadingProvider.notifier);
    if (ref.read(serialScanLoadingProvider)) return;

    loadingNotifier.state = true;
    try {
      state = await _listPorts();
    } catch (_) {
      state = [];
    } finally {
      loadingNotifier.state = false;
    }
  }
}

/// Enumerates serial port names.
///
/// On Windows, `SerialPort.availablePorts` can block for seconds when querying
/// Bluetooth virtual COM ports. We query `HKLM\HARDWARE\DEVICEMAP\SERIALCOMM`
/// directly for instantaneous enumeration. Other platforms fall back to an isolate.
Future<List<String>> _listPorts() async {
  if (Platform.isWindows) return _listWindowsPorts();
  try {
    final ports = await Isolate.run(() => SerialPort.availablePorts);
    return ports.toSet().toList();
  } catch (_) {
    return [];
  }
}

/// Reads active COM ports directly from the Windows registry.
Future<List<String>> _listWindowsPorts() async {
  try {
    final result = await Process.run('reg', [
      'query',
      r'HKLM\HARDWARE\DEVICEMAP\SERIALCOMM',
    ]);
    if (result.exitCode != 0) return const [];

    const marker = 'REG_SZ';
    final ports = <String>{};
    for (final line in (result.stdout as String).split('\n')) {
      final i = line.indexOf(marker);
      if (i == -1) continue;
      final name = line.substring(i + marker.length).trim();
      if (name.isNotEmpty) ports.add(name);
    }

    // Natural sort so COM2 precedes COM10 instead of lexical order.
    final sorted = ports.toList()
      ..sort((a, b) {
        final na = int.tryParse(a.replaceAll(RegExp(r'\D'), ''));
        final nb = int.tryParse(b.replaceAll(RegExp(r'\D'), ''));
        if (na != null && nb != null) return na.compareTo(nb);
        return a.compareTo(b);
      });
    return sorted;
  } catch (_) {
    return [];
  }
}
