import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import '../models/terminal_tab.dart';
import 'paste_settings_provider.dart';

const _boxName = 'app_settings';
const _tabsKey = 'terminal_tabs';
const _serialCountKey = 'terminal_serial_count';
const _ptyCountKey = 'terminal_pty_count';
const _activeTabIdKey = 'terminal_active_tab_id';
const _serialActiveTabIdKey = 'terminal_serial_active_tab_id';
const _terminalFoldedKey = 'terminal_folded';
const _mainPanelFoldedKey = 'main_panel_folded';
const _mainFlexKey = 'terminal_main_flex';
const _logFlexKey = 'terminal_log_flex';
const _paneFlexesKey = 'terminal_pane_flexes';
const _ptyShellKey = 'terminal_pty_shell';

/// Supported Windows PTY shells.
enum PtyShellType {
  cmd('cmd.exe', 'cmd.exe', ['/k', 'chcp', '65001']),
  powershell('PowerShell', 'powershell.exe', ['-NoLogo']),
  pwsh('PowerShell 7', 'pwsh.exe', ['-NoLogo']);

  const PtyShellType(this.label, this.executable, this.arguments);

  final String label;
  final String executable;
  final List<String> arguments;
}

/// Global provider for the preferred Windows PTY shell.
final ptyShellProvider = NotifierProvider<PtyShellNotifier, PtyShellType>(
  PtyShellNotifier.new,
);

/// Manages and persists the selected Windows PTY shell in Hive.
class PtyShellNotifier extends Notifier<PtyShellType> {
  @override
  PtyShellType build() {
    if (!Hive.isBoxOpen(_boxName)) return PtyShellType.cmd;
    final raw = Hive.box<String>(_boxName).get(_ptyShellKey);
    return PtyShellType.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => PtyShellType.cmd,
    );
  }

  void setShell(PtyShellType shell) {
    state = shell;
    if (Hive.isBoxOpen(_boxName)) {
      Hive.box<String>(_boxName).put(_ptyShellKey, shell.name);
    }
  }
}

bool _readBool(String key, {bool defaultValue = false}) {
  if (!Hive.isBoxOpen(_boxName)) return defaultValue;
  final raw = Hive.box<String>(_boxName).get(key);
  if (raw == null) return defaultValue;
  return raw == 'true';
}

void _writeBool(String key, bool value) {
  if (Hive.isBoxOpen(_boxName)) {
    Hive.box<String>(_boxName).put(key, value.toString());
  }
}

/// Persisted split ratios and pane flexes for the terminal window.
class TerminalLayoutPersistence {
  static (double mainFlex, double logFlex) readVerticalFlex() {
    if (!Hive.isBoxOpen(_boxName)) return (3.0, 1.0);
    final box = Hive.box<String>(_boxName);
    final mainFlex = double.tryParse(box.get(_mainFlexKey) ?? '') ?? 3.0;
    final logFlex = double.tryParse(box.get(_logFlexKey) ?? '') ?? 1.0;
    return (
      mainFlex > 0 ? mainFlex : 3.0,
      logFlex > 0 ? logFlex : 1.0,
    );
  }

  static void saveVerticalFlex(double mainFlex, double logFlex) {
    if (!Hive.isBoxOpen(_boxName)) return;
    if (mainFlex <= 0 || logFlex <= 0) return;
    final box = Hive.box<String>(_boxName);
    box.put(_mainFlexKey, mainFlex.toString());
    box.put(_logFlexKey, logFlex.toString());
  }

  static Map<String, double> readPaneFlexes() {
    if (!Hive.isBoxOpen(_boxName)) return const {};
    final raw = Hive.box<String>(_boxName).get(_paneFlexesKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <String, double>{};
      for (final entry in decoded.entries) {
        final v = (entry.value as num?)?.toDouble();
        if (v != null && v > 0) {
          result[entry.key] = v;
        }
      }
      return result;
    } catch (_) {
      return const {};
    }
  }

  static void savePaneFlexes(Map<String, double> flexes) {
    if (!Hive.isBoxOpen(_boxName)) return;
    Hive.box<String>(_boxName).put(_paneFlexesKey, jsonEncode(flexes));
  }

  static String? readSerialActiveTabId() {
    if (!Hive.isBoxOpen(_boxName)) return null;
    final val = Hive.box<String>(_boxName).get(_serialActiveTabIdKey);
    return (val != null && val.isNotEmpty) ? val : null;
  }

  static void saveSerialActiveTabId(String? id) {
    if (!Hive.isBoxOpen(_boxName)) return;
    final box = Hive.box<String>(_boxName);
    if (id == null || id.isEmpty) {
      box.delete(_serialActiveTabIdKey);
    } else {
      box.put(_serialActiveTabIdKey, id);
    }
  }
}

/// Indicates whether terminal screen updates are paused.
final terminalPausedProvider = StateProvider<bool>((ref) => false);

/// Indicates whether the bottom terminal panel is folded/collapsed vertically.
final terminalFoldedProvider = NotifierProvider<TerminalFoldedNotifier, bool>(
  TerminalFoldedNotifier.new,
);

/// Notifier that manages and persists whether the terminal panel is folded.
class TerminalFoldedNotifier extends Notifier<bool> {
  @override
  bool build() {
    listenSelf((prev, next) => _writeBool(_terminalFoldedKey, next));
    return _readBool(_terminalFoldedKey);
  }

  @override
  bool get state => super.state;

  @override
  set state(bool value) => super.state = value;
}

/// Indicates whether the top main panel is folded/collapsed vertically so the
/// terminal panel occupies most of the window.
final mainPanelFoldedProvider = NotifierProvider<MainPanelFoldedNotifier, bool>(
  MainPanelFoldedNotifier.new,
);

/// Notifier that manages and persists whether the main panel is folded.
class MainPanelFoldedNotifier extends Notifier<bool> {
  @override
  bool build() {
    listenSelf((prev, next) => _writeBool(_mainPanelFoldedKey, next));
    return _readBool(_terminalFoldedKey)
        ? false
        : _readBool(_mainPanelFoldedKey);
  }

  @override
  bool get state => super.state;

  @override
  set state(bool value) => super.state = value;
}

/// Global provider for managing active terminal tabs.
final terminalTabsNotifierProvider =
    NotifierProvider<TerminalTabsNotifier, List<TerminalTab>>(
      TerminalTabsNotifier.new,
    );

/// Manages the list of active terminal tabs/panes and persists status to Hive.
class TerminalTabsNotifier extends Notifier<List<TerminalTab>> {
  int _serialCount = 1;
  int _ptyCount = 1;

  @override
  List<TerminalTab> build() {
    final pasteSettings = ref.read(pasteSettingsNotifierProvider);
    final restored = _restoreFromHive(pasteSettings);
    if (restored != null && restored.isNotEmpty) {
      return restored;
    }

    _serialCount = 1;
    _ptyCount = 1;
    final defaults = [
      TerminalTab(
        id: 'serial_0',
        type: TerminalTabType.serial,
        label: 'SERIAL',
        pasteCharDelayMs: pasteSettings.charDelayMs,
        pasteLineDelayMs: pasteSettings.lineDelayMs,
      ),
      TerminalTab(
        id: 'pty_0',
        type: TerminalTabType.pty,
        label: 'PTY',
        pasteCharDelayMs: pasteSettings.charDelayMs,
        pasteLineDelayMs: pasteSettings.lineDelayMs,
      ),
    ];
    _saveToHive(defaults);
    return defaults;
  }

  List<TerminalTab>? _restoreFromHive(PasteSettings pasteSettings) {
    if (!Hive.isBoxOpen(_boxName)) return null;
    final box = Hive.box<String>(_boxName);
    final raw = box.get(_tabsKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final tabs = <TerminalTab>[];
      int maxSerial = 0;
      int maxPty = 0;

      for (final item in list) {
        if (item is! Map) continue;
        final id = item['id']?.toString() ?? '';
        final typeStr = item['type']?.toString() ?? '';
        final label = item['label']?.toString() ?? '';
        if (id.isEmpty || label.isEmpty) continue;

        final type = typeStr == 'serial'
            ? TerminalTabType.serial
            : TerminalTabType.pty;

        tabs.add(
          TerminalTab(
            id: id,
            type: type,
            label: label,
            pasteCharDelayMs: pasteSettings.charDelayMs,
            pasteLineDelayMs: pasteSettings.lineDelayMs,
          ),
        );

        final numSuffix = _extractLabelNumber(label);
        if (type == TerminalTabType.serial) {
          if (numSuffix > maxSerial) maxSerial = numSuffix;
        } else {
          if (numSuffix > maxPty) maxPty = numSuffix;
        }
      }

      if (tabs.isEmpty) return null;

      final savedSerialCount =
          int.tryParse(box.get(_serialCountKey) ?? '') ?? maxSerial;
      final savedPtyCount =
          int.tryParse(box.get(_ptyCountKey) ?? '') ?? maxPty;

      _serialCount = savedSerialCount > maxSerial ? savedSerialCount : maxSerial;
      _ptyCount = savedPtyCount > maxPty ? savedPtyCount : maxPty;
      return tabs;
    } catch (_) {
      return null;
    }
  }

  int _extractLabelNumber(String label) {
    final parts = label.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final parsed = int.tryParse(parts.last);
      if (parsed != null && parsed > 0) return parsed;
    }
    return 1;
  }

  void _saveToHive(List<TerminalTab> tabs) {
    if (!Hive.isBoxOpen(_boxName)) return;
    final box = Hive.box<String>(_boxName);
    final data = [
      for (final t in tabs)
        {
          'id': t.id,
          'type': t.type == TerminalTabType.serial ? 'serial' : 'pty',
          'label': t.label,
        },
    ];
    box.put(_tabsKey, jsonEncode(data));
    box.put(_serialCountKey, _serialCount.toString());
    box.put(_ptyCountKey, _ptyCount.toString());
  }

  /// Adds a new serial terminal tab and persists terminal state.
  void addSerial() {
    final hasSerial = state.any((t) => t.type == TerminalTabType.serial);
    if (!hasSerial) {
      _serialCount = 1;
    } else {
      _serialCount++;
    }
    final label = _serialCount == 1 ? 'SERIAL' : 'SERIAL $_serialCount';
    final pasteSettings = ref.read(pasteSettingsNotifierProvider);
    final newTab = TerminalTab(
      id: 'serial_${DateTime.now().millisecondsSinceEpoch}',
      type: TerminalTabType.serial,
      label: label,
      pasteCharDelayMs: pasteSettings.charDelayMs,
      pasteLineDelayMs: pasteSettings.lineDelayMs,
    );
    state = [...state, newTab];
    _saveToHive(state);
    ref.read(activeTabIdProvider.notifier).setActive(newTab.id);
  }

  /// Adds a new PTY shell terminal tab and persists terminal state.
  void addPty() {
    final hasPty = state.any((t) => t.type == TerminalTabType.pty);
    if (!hasPty) {
      _ptyCount = 1;
    } else {
      _ptyCount++;
    }
    final label = _ptyCount == 1 ? 'PTY' : 'PTY $_ptyCount';
    final pasteSettings = ref.read(pasteSettingsNotifierProvider);
    final newTab = TerminalTab(
      id: 'pty_${DateTime.now().millisecondsSinceEpoch}',
      type: TerminalTabType.pty,
      label: label,
      pasteCharDelayMs: pasteSettings.charDelayMs,
      pasteLineDelayMs: pasteSettings.lineDelayMs,
    );
    state = [...state, newTab];
    _saveToHive(state);
    ref.read(activeTabIdProvider.notifier).setActive(newTab.id);
  }

  /// Closes the tab with [id] if more than 1 tab remains and persists terminal state.
  void removeTab(String id) {
    if (state.length <= 1) return;
    state = state.where((t) => t.id != id).toList();
    if (!state.any((t) => t.type == TerminalTabType.serial)) {
      _serialCount = 0;
    }
    if (!state.any((t) => t.type == TerminalTabType.pty)) {
      _ptyCount = 0;
    }
    _saveToHive(state);
    final activeId = ref.read(activeTabIdProvider);
    if (activeId == id) {
      ref.read(activeTabIdProvider.notifier).setActive(state.firstOrNull?.id);
    }
  }
}

/// Global provider tracking the currently focused terminal tab ID.
final activeTabIdProvider = NotifierProvider<ActiveTabIdNotifier, String?>(
  ActiveTabIdNotifier.new,
);

/// Notifier tracking and persisting the currently focused tab ID.
class ActiveTabIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    if (!Hive.isBoxOpen(_boxName)) return null;
    final saved = Hive.box<String>(_boxName).get(_activeTabIdKey);
    if (saved == null || saved.isEmpty) return null;
    final tabs = ref.read(terminalTabsNotifierProvider);
    if (tabs.any((t) => t.id == saved)) {
      return saved;
    }
    return tabs.firstOrNull?.id;
  }

  void setActive(String? id) {
    state = id;
    if (!Hive.isBoxOpen(_boxName)) return;
    final box = Hive.box<String>(_boxName);
    if (id == null || id.isEmpty) {
      box.delete(_activeTabIdKey);
    } else {
      box.put(_activeTabIdKey, id);
    }
  }
}

