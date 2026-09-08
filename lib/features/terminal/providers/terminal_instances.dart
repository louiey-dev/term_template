import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/terminal_tab.dart';
import 'paste_settings_provider.dart';

/// Indicates whether terminal screen updates are paused.
final terminalPausedProvider = StateProvider<bool>((ref) => false);

/// Indicates whether the bottom terminal panel is folded/collapsed vertically.
final terminalFoldedProvider = StateProvider<bool>((ref) => false);

/// Global provider for managing active terminal tabs.
final terminalTabsNotifierProvider =
    NotifierProvider<TerminalTabsNotifier, List<TerminalTab>>(
      TerminalTabsNotifier.new,
    );

/// Manages the list of active terminal tabs/panes.
class TerminalTabsNotifier extends Notifier<List<TerminalTab>> {
  int _serialCount = 1;
  int _ptyCount = 1;

  @override
  List<TerminalTab> build() {
    final pasteSettings = ref.read(pasteSettingsNotifierProvider);
    return [
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
  }

  /// Adds a new serial terminal tab.
  void addSerial() {
    _serialCount++;
    final pasteSettings = ref.read(pasteSettingsNotifierProvider);
    state = [
      ...state,
      TerminalTab(
        id: 'serial_${DateTime.now().millisecondsSinceEpoch}',
        type: TerminalTabType.serial,
        label: 'SERIAL $_serialCount',
        pasteCharDelayMs: pasteSettings.charDelayMs,
        pasteLineDelayMs: pasteSettings.lineDelayMs,
      ),
    ];
  }

  /// Adds a new PTY shell terminal tab.
  void addPty() {
    _ptyCount++;
    final pasteSettings = ref.read(pasteSettingsNotifierProvider);
    state = [
      ...state,
      TerminalTab(
        id: 'pty_${DateTime.now().millisecondsSinceEpoch}',
        type: TerminalTabType.pty,
        label: 'PTY $_ptyCount',
        pasteCharDelayMs: pasteSettings.charDelayMs,
        pasteLineDelayMs: pasteSettings.lineDelayMs,
      ),
    ];
  }

  /// Closes the tab with [id] if more than 1 tab remains.
  void removeTab(String id) {
    if (state.length <= 1) return;
    state = state.where((t) => t.id != id).toList();
  }
}

/// Global provider tracking the currently focused terminal tab ID.
final activeTabIdProvider = NotifierProvider<ActiveTabIdNotifier, String?>(
  ActiveTabIdNotifier.new,
);

/// Notifier tracking the currently focused tab ID.
class ActiveTabIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setActive(String? id) => state = id;
}
