import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../terminal/models/terminal_tab.dart';
import '../../terminal/providers/terminal_instances.dart';
import 'board_console.dart';
import 'serial_pane_provider.dart';

/// A [BoardConsole] adapter backed by an active serial connection.
class SerialBoardConsole implements BoardConsole {
  SerialBoardConsole({required this.id, required this.notifier});

  @override
  final String id;
  final SerialPaneNotifier notifier;

  @override
  ConsoleKind get kind => ConsoleKind.serial;

  @override
  bool get isConnected => notifier.isConnected;

  @override
  Future<String> run(
    String command, {
    Duration timeout = const Duration(seconds: 4),
  }) => notifier.runCommand(command, timeout: timeout);

  @override
  void send(String data) => notifier.send(data);
}

/// Selects the preferred connected console (Serial first, then PTY).
BoardConsole? pickBoardConsole(WidgetRef ref) {
  final activeId = ref.read(activeTabIdProvider);

  // 1. Try currently focused tab first
  if (activeId != null) {
    final tabs = ref.read(terminalTabsNotifierProvider);
    TerminalTab? activeTab;
    for (final t in tabs) {
      if (t.id == activeId) {
        activeTab = t;
        break;
      }
    }
    if (activeTab != null) {
      if (activeTab.type == TerminalTabType.serial) {
        final notifier = ref.read(
          serialPaneNotifierProvider(activeId).notifier,
        );
        if (notifier.isConnected) {
          return SerialBoardConsole(id: activeId, notifier: notifier);
        }
      } else if (activeTab.type == TerminalTabType.pty) {
        for (final console in ref.read(boardConsoleRegistryProvider).all) {
          if (console.id == activeId && console.isConnected) {
            return console;
          }
        }
      }
    }
  }

  // 2. Fallback to any connected Serial pane
  for (final tab in ref.read(terminalTabsNotifierProvider)) {
    if (tab.type != TerminalTabType.serial) continue;
    if (tab.id == activeId) continue;
    final notifier = ref.read(serialPaneNotifierProvider(tab.id).notifier);
    if (notifier.isConnected) {
      return SerialBoardConsole(id: tab.id, notifier: notifier);
    }
  }

  // 3. Fallback to any connected PTY pane
  for (final console in ref.read(boardConsoleRegistryProvider).all) {
    if (console.id == activeId) continue;
    if (console.kind == ConsoleKind.pty && console.isConnected) {
      return console;
    }
  }
  return null;
}
