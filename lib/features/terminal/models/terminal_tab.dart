import 'package:flutter/widgets.dart';
import 'package:xterm/xterm.dart';

/// Type of terminal session.
enum TerminalTabType { serial, pty }

/// Represents an active terminal tab/pane with its associated [Terminal],
/// [TerminalController], and [FocusNode].
class TerminalTab {
  TerminalTab({
    required this.id,
    required this.type,
    required this.label,
    int maxLines = 10000,
    int pasteCharDelayMs = 0,
    int pasteLineDelayMs = 0,
  }) : terminal = Terminal(maxLines: maxLines),
       controller = TerminalController(),
       focusNode = FocusNode(debugLabel: 'terminal_$id') {
    terminal.pasteCharDelayMs = pasteCharDelayMs;
    terminal.pasteLineDelayMs = pasteLineDelayMs;
  }

  final String id;
  final TerminalTabType type;
  final String label;
  final Terminal terminal;
  final TerminalController controller;

  /// Keyboard focus node for this pane's [TerminalView].
  final FocusNode focusNode;

  /// Configures paste character and line delays to avoid buffer overflow.
  void setPasteDelay(int charDelayMs, int lineDelayMs) {
    terminal.pasteCharDelayMs = charDelayMs;
    terminal.pasteLineDelayMs = lineDelayMs;
  }
}
