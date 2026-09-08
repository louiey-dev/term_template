import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:xterm/xterm.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/file_logger_service.dart';
import '../../connection/providers/board_console.dart';
import '../../connection/providers/serial_pane_provider.dart';
import '../../panels/common/board_command.dart';
import '../models/terminal_tab.dart';
import '../providers/paste_settings_provider.dart';
import '../providers/terminal_credentials_provider.dart';
import '../providers/terminal_instances.dart';

/// Bottom dock containing one or more terminal panes in a horizontal split view.
class LogPanel extends ConsumerStatefulWidget {
  const LogPanel({super.key});

  @override
  ConsumerState<LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends ConsumerState<LogPanel> {
  late final MultiSplitViewController _splitController;
  final Map<String, Pty> _ptys = {};
  final Map<String, PtyConsole> _consoles = {};
  final Set<String> _ptyStarted = {};
  final Map<String, Timer> _ptyResizeDebouncers = {};
  late final BoardConsoleRegistry _registry;

  @override
  void initState() {
    super.initState();
    _registry = ref.read(boardConsoleRegistryProvider);
    final tabs = ref.read(terminalTabsNotifierProvider);
    _splitController = MultiSplitViewController(
      areas: [for (final t in tabs) Area(id: t.id, flex: 1)],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensurePtys(tabs);
    });
  }

  @override
  void dispose() {
    _splitController.dispose();
    for (final timer in _ptyResizeDebouncers.values) {
      timer.cancel();
    }
    _ptyResizeDebouncers.clear();
    for (final id in _consoles.keys) {
      _registry.unregister(id);
    }
    for (final pty in _ptys.values) {
      pty.kill();
    }
    super.dispose();
  }

  void _syncAreas(List<TerminalTab> tabs) {
    final existing = {for (final a in _splitController.areas) a.id: a};
    _splitController.areas = [
      for (final t in tabs) existing[t.id] ?? Area(id: t.id, flex: 1),
    ];
  }

  void _ensurePtys(List<TerminalTab> tabs) {
    for (final tab in tabs) {
      if (tab.type == TerminalTabType.pty && !_ptyStarted.contains(tab.id)) {
        _ptyStarted.add(tab.id);
        _startPty(tab);
      }
    }
  }

  void _onTabsChanged(List<TerminalTab>? prev, List<TerminalTab> next) {
    if (!mounted) return;
    if (prev != null) {
      final removed = prev.map((t) => t.id).toSet()
        ..removeAll(next.map((t) => t.id));
      for (final id in removed) {
        _ptys[id]?.kill();
        _ptys.remove(id);
        _consoles[id]?.markClosed();
        _consoles.remove(id);
        _registry.unregister(id);
        _ptyStarted.remove(id);
        _ptyResizeDebouncers.remove(id)?.cancel();
      }
    }
    _syncAreas(next);
    _ensurePtys(next);
  }

  void _startPty(TerminalTab tab) {
    if (!mounted) return;
    try {
      final pty = Pty.start(
        _shell,
        arguments: _shellArgs,
        columns: tab.terminal.viewWidth,
        rows: tab.terminal.viewHeight,
        environment: {...Platform.environment, 'TERM': 'xterm-256color'},
      );
      _ptys[tab.id] = pty;
      final console = PtyConsole(id: tab.id, pty: pty);
      _consoles[tab.id] = console;
      _registry.register(console);

      pty.output
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen((data) {
            console.feed(data);
            if (!ref.read(terminalPausedProvider)) {
              tab.terminal.write(data);
              ref.read(fileLoggerNotifierProvider.notifier).log(data);
            }
          });

      pty.exitCode.then((code) {
        console.markClosed();
        tab.terminal.write('\r\n[Process exited with code $code]\r\n');
      });

      tab.terminal.onOutput = (data) {
        try {
          pty.write(const Utf8Encoder().convert(data));
        } catch (_) {}
      };

      tab.terminal.onResize = (w, h, pw, ph) {
        _ptyResizeDebouncers[tab.id]?.cancel();
        _ptyResizeDebouncers[tab.id] = Timer(
          const Duration(milliseconds: 100),
          () {
            try {
              pty.resize(h, w);
            } catch (_) {}
          },
        );
      };
    } catch (e) {
      tab.terminal.write('Failed to start PTY shell: $e\r\n');
    }
  }

  String get _shell => Platform.isWindows
      ? 'cmd.exe'
      : (Platform.environment['SHELL'] ?? 'bash');

  List<String> get _shellArgs =>
      Platform.isWindows ? ['/k', 'chcp', '65001'] : [];

  TerminalTab? _findTab(List<TerminalTab> tabs, Object? id) {
    for (final t in tabs) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tabs = ref.watch(terminalTabsNotifierProvider);
    final activeTabId = ref.watch(activeTabIdProvider) ?? tabs.firstOrNull?.id;
    ref.listen<List<TerminalTab>>(terminalTabsNotifierProvider, _onTabsChanged);

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxH = constraints.maxHeight;
          if (maxH <= 0) return const SizedBox.shrink();

          if (maxH <= 32) {
            return ClipRect(
              child: SizedBox(
                height: maxH,
                child: _Toolbar(
                  isPaused: ref.watch(terminalPausedProvider),
                  onPause: () {
                    final notifier = ref.read(terminalPausedProvider.notifier);
                    notifier.state = !notifier.state;
                  },
                ),
              ),
            );
          }

          return ClipRect(
            child: Column(
              children: [
                _Toolbar(
                  isPaused: ref.watch(terminalPausedProvider),
                  onPause: () {
                    final notifier = ref.read(terminalPausedProvider.notifier);
                    notifier.state = !notifier.state;
                  },
                ),
                Expanded(
                  child: MultiSplitViewTheme(
                    data: MultiSplitViewThemeData(
                      dividerThickness: 4,
                      dividerPainter: DividerPainters.background(
                        color: c.border,
                        highlightedColor: c.primary,
                      ),
                    ),
                    child: MultiSplitView(
                      axis: Axis.horizontal,
                      controller: _splitController,
                      builder: (context, area) {
                        final tab = _findTab(tabs, area.id);
                        if (tab == null) return const SizedBox.shrink();
                        final isSerial = tab.type == TerminalTabType.serial;
                        return _TerminalPane(
                          tab: tab,
                          canClose: tabs.length > 1,
                          isActive: tab.id == activeTabId,
                          onActivate: () {
                            ref
                                .read(activeTabIdProvider.notifier)
                                .setActive(tab.id);
                            if (isSerial) {
                              ref
                                      .read(serialActiveTabIdProvider.notifier)
                                      .state =
                                  tab.id;
                            }
                            tab.focusNode.requestFocus();
                          },
                          onClose: () => ref
                              .read(terminalTabsNotifierProvider.notifier)
                              .removeTab(tab.id),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TerminalPane extends ConsumerWidget {
  const _TerminalPane({
    required this.tab,
    required this.canClose,
    required this.isActive,
    required this.onActivate,
    required this.onClose,
  });

  final TerminalTab tab;
  final bool canClose;
  final bool isActive;
  final VoidCallback? onActivate;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final isSerial = tab.type == TerminalTabType.serial;
    final icon = isSerial ? Icons.usb_outlined : Icons.terminal;

    SerialStatus? status;
    String port = '';
    if (isSerial) {
      final state = ref.watch(serialPaneNotifierProvider(tab.id));
      status = state.status;
      port = state.config.port;
    }

    final headerColor = isActive ? c.surface : c.sidebar;
    final labelColor = isActive ? c.primary : c.foreground;

    final header = Container(
      height: 28,
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: headerColor,
        border: Border(
          bottom: BorderSide(
            color: isActive ? c.primary : c.border,
            width: isActive ? 1.5 : 1,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          const minHeaderW = 200.0;
          final effectiveW = maxW < minHeaderW ? minHeaderW : maxW;

          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: effectiveW,
              maxWidth: effectiveW,
              minHeight: 28,
              maxHeight: 28,
              child: SizedBox(
                width: effectiveW,
                height: 28,
                child: Row(
                  children: [
                    if (status != null) ...[
                      _StatusDot(status: status),
                      const SizedBox(width: 6),
                    ],
                    Icon(icon, size: 12, color: c.muted),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tab.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: labelColor,
                        ),
                      ),
                    ),
                    if (port.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          port,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'Consolas',
                            fontWeight: FontWeight.w600,
                            color: c.primary,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    _MiniBtn(
                      icon: Icons.delete_outline,
                      tooltip: 'Clear',
                      color: c.muted,
                      onTap: () {
                        tab.terminal.buffer.clear();
                        tab.terminal.buffer.setCursor(0, 0);
                        tab.controller.clearSelection();
                      },
                    ),
                    if (canClose)
                      _MiniBtn(
                        icon: Icons.close,
                        tooltip: 'Close',
                        color: c.muted,
                        onTap: onClose,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => onActivate?.call(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxH = constraints.maxHeight;
          if (maxH <= 0) return const SizedBox.shrink();

          if (maxH <= 28) {
            return ClipRect(
              child: SizedBox(height: maxH, child: header),
            );
          }
          return ClipRect(
            child: Column(
              children: [
                header,
                // Terminal View
                Expanded(
                  child: ClipRect(
                    child: TerminalView(
                      tab.terminal,
                      controller: tab.controller,
                      focusNode: tab.focusNode,
                      theme: buildTerminalTheme(
                        c,
                        Theme.of(context).brightness,
                      ),
                      backgroundOpacity: 0.0,
                      padding: const EdgeInsets.all(8),
                      onSecondaryTapDown: (d, o) => _handleRightClick(tab),
                      hardwareKeyboardOnly: true,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleRightClick(TerminalTab tab) async {
    final selection = tab.controller.selection;
    if (selection != null) {
      final text = tab.terminal.buffer.getText(selection);
      tab.controller.clearSelection();
      await Clipboard.setData(ClipboardData(text: text));
    } else {
      final data = await Clipboard.getData('text/plain');
      if (data?.text != null) await tab.terminal.paste(data!.text!);
    }
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.isPaused, required this.onPause});

  final bool isPaused;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final logState = ref.watch(fileLoggerNotifierProvider);
    final logNotifier = ref.read(fileLoggerNotifierProvider.notifier);
    final tabsNotifier = ref.read(terminalTabsNotifierProvider.notifier);
    final isFolded = ref.watch(terminalFoldedProvider);
    final foldNotifier = ref.read(terminalFoldedProvider.notifier);

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          const minToolbarW = 900.0;
          final effectiveW = maxW < minToolbarW ? minToolbarW : maxW;

          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: effectiveW,
              maxWidth: effectiveW,
              minHeight: 32,
              maxHeight: 32,
              child: SizedBox(
                width: effectiveW,
                height: 32,
                child: Row(
                  children: [
                    // Vertical Fold / Unfold Toggle
                    _MiniBtn(
                      icon: isFolded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      tooltip: isFolded
                          ? 'Expand Terminal (Alt+T)'
                          : 'Fold Terminal (Alt+T)',
                      color: isFolded ? c.primary : c.muted,
                      onTap: () => foldNotifier.state = !isFolded,
                    ),
                    const SizedBox(width: 4),
                    // Terminal Title (clickable to expand when folded)
                    InkWell(
                      onTap: isFolded ? () => foldNotifier.state = false : null,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.terminal,
                              size: 13,
                              color: isFolded ? c.muted : c.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'TERMINAL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: isFolded ? c.muted : c.foreground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: 'New Terminal Pane',
                      color: c.card,
                      icon: Icon(Icons.add, size: 16, color: c.muted),
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      onSelected: (val) => switch (val) {
                        'serial' => tabsNotifier.addSerial(),
                        _ => tabsNotifier.addPty(),
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'serial',
                          child: Row(
                            children: [
                              Icon(Icons.usb, size: 14, color: c.muted),
                              const SizedBox(width: 8),
                              Text(
                                'New Serial',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.foreground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'pty',
                          child: Row(
                            children: [
                              Icon(Icons.terminal, size: 14, color: c.muted),
                              const SizedBox(width: 8),
                              Text(
                                'New PTY',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.foreground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const _CredentialsFields(),
                    const SizedBox(width: 8),
                    // Pause / Resume
                    _MiniBtn(
                      icon: isPaused ? Icons.play_arrow : Icons.pause,
                      tooltip: isPaused ? 'Resume' : 'Pause',
                      color: isPaused ? c.primary : c.muted,
                      onTap: onPause,
                    ),
                    // Save to file
                    _MiniBtn(
                      icon: logState.isLogging
                          ? Icons.stop
                          : Icons.save_outlined,
                      tooltip: logState.isLogging
                          ? 'Stop logging'
                          : 'Save to file',
                      color: logState.isLogging ? c.destructive : c.muted,
                      onTap: () async {
                        if (logState.isLogging) {
                          await logNotifier.stopLogging();
                        } else {
                          await logNotifier.startLogging();
                        }
                      },
                    ),
                    // Timestamp toggle
                    _MiniBtn(
                      icon: Icons.schedule,
                      tooltip: 'Timestamp each line',
                      color: logState.timestampEnabled ? c.primary : c.muted,
                      onTap: () =>
                          logNotifier.setTimestamp(!logState.timestampEnabled),
                    ),
                    const SizedBox(width: 4),
                    // Paste delay settings
                    const _PasteDelayBtn(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PasteDelayBtn extends ConsumerWidget {
  const _PasteDelayBtn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final pasteSettings = ref.watch(pasteSettingsNotifierProvider);
    final pasteNotifier = ref.read(pasteSettingsNotifierProvider.notifier);

    return PopupMenuButton<String>(
      tooltip: pasteSettings.label,
      color: c.card,
      icon: Icon(
        Icons.speed,
        size: 16,
        color: pasteSettings.hasDelay ? c.primary : c.muted,
      ),
      iconSize: 16,
      padding: EdgeInsets.zero,
      onSelected: (val) {
        switch (val) {
          case 'off':
            pasteNotifier.setPreset(0, 0);
            break;
          case 'fast':
            pasteNotifier.setPreset(5, 0);
            break;
          case 'medium':
            pasteNotifier.setPreset(10, 0);
            break;
          case 'slow':
            pasteNotifier.setPreset(20, 100);
            break;
          case 'custom':
            _showCustomDelayDialog(context, ref);
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          height: 28,
          child: Text(
            'PASTE DELAY SETTINGS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: c.muted,
            ),
          ),
        ),
        const PopupMenuDivider(height: 4),
        PopupMenuItem(
          value: 'off',
          child: _presetRow(c, 'Off (0 ms)', !pasteSettings.hasDelay),
        ),
        PopupMenuItem(
          value: 'fast',
          child: _presetRow(
            c,
            'Fast (5 ms / char)',
            pasteSettings.charDelayMs == 5 && pasteSettings.lineDelayMs == 0,
          ),
        ),
        PopupMenuItem(
          value: 'medium',
          child: _presetRow(
            c,
            'Medium (10 ms / char)',
            pasteSettings.charDelayMs == 10 && pasteSettings.lineDelayMs == 0,
          ),
        ),
        PopupMenuItem(
          value: 'slow',
          child: _presetRow(
            c,
            'Slow (20 ms / char, 100 ms / line)',
            pasteSettings.charDelayMs == 20 && pasteSettings.lineDelayMs == 100,
          ),
        ),
        const PopupMenuDivider(height: 4),
        PopupMenuItem(
          value: 'custom',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 14, color: c.muted),
              const SizedBox(width: 8),
              Text(
                'Custom Delay...',
                style: TextStyle(fontSize: 12, color: c.foreground),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _presetRow(AppColors c, String label, bool isSelected) {
    return Row(
      children: [
        Icon(
          isSelected ? Icons.check : Icons.circle_outlined,
          size: 14,
          color: isSelected ? c.primary : c.muted,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? c.primary : c.foreground,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  void _showCustomDelayDialog(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final current = ref.read(pasteSettingsNotifierProvider);
    final charCtrl = TextEditingController(
      text: current.charDelayMs.toString(),
    );
    final lineCtrl = TextEditingController(
      text: current.lineDelayMs.toString(),
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        title: Text(
          'Custom Terminal Paste Delay',
          style: TextStyle(
            fontSize: 15,
            color: c.foreground,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add delay when pasting text to prevent serial receiver buffer overflow.',
              style: TextStyle(fontSize: 12, color: c.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: charCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Char Delay (ms)',
                hintText: 'e.g. 10',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lineCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Line Delay (ms)',
                hintText: 'e.g. 100',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.muted)),
          ),
          ElevatedButton(
            onPressed: () {
              final charMs = int.tryParse(charCtrl.text) ?? 0;
              final lineMs = int.tryParse(lineCtrl.text) ?? 0;
              ref
                  .read(pasteSettingsNotifierProvider.notifier)
                  .setPreset(charMs, lineMs);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final SerialStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (status) {
      SerialStatus.connected => c.success,
      SerialStatus.connecting => c.warning,
      SerialStatus.disconnected => c.muted.withValues(alpha: 0.5),
    };
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _CredentialsFields extends ConsumerStatefulWidget {
  const _CredentialsFields();

  @override
  ConsumerState<_CredentialsFields> createState() => _CredentialsFieldsState();
}

class _CredentialsFieldsState extends ConsumerState<_CredentialsFields> {
  late final TextEditingController _ipController;
  late final TextEditingController _idController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(terminalCredentialsNotifierProvider);
    _ipController = TextEditingController(text: initial.ip);
    _idController = TextEditingController(text: initial.id);
    _passwordController = TextEditingController(text: initial.password);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    ref.listen<TerminalCredentials>(terminalCredentialsNotifierProvider, (
      prev,
      next,
    ) {
      if (next.ip != _ipController.text) {
        _ipController.text = next.ip;
      }
      if (next.id != _idController.text) {
        _idController.text = next.id;
      }
      if (next.password != _passwordController.text) {
        _passwordController.text = next.password;
      }
    });

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              backgroundColor: c.surface,
              foregroundColor: c.primary,
              elevation: 0,
              textStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: () {
              final ip = _ipController.text.trim();
              final id = _idController.text.trim();
              if (ip.isEmpty || id.isEmpty) return;
              sendBoardCommand(ref, context, 'ssh $id@$ip');
            },
            child: const Text('SSH'),
          ),
        ),
        const SizedBox(width: 6),
        _buildField(
          controller: _ipController,
          hintText: 'IP Address',
          width: 120,
          onChanged: (val) => ref
              .read(terminalCredentialsNotifierProvider.notifier)
              .updateIp(val),
        ),
        const SizedBox(width: 6),
        _buildField(
          controller: _idController,
          hintText: 'ID',
          width: 80,
          onChanged: (val) => ref
              .read(terminalCredentialsNotifierProvider.notifier)
              .updateId(val),
        ),
        const SizedBox(width: 6),
        _buildField(
          controller: _passwordController,
          hintText: 'Password',
          width: 100,
          obscureText: true,
          onChanged: (val) => ref
              .read(terminalCredentialsNotifierProvider.notifier)
              .updatePassword(val),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hintText,
    required double width,
    required ValueChanged<String> onChanged,
    bool obscureText = false,
  }) {
    final c = context.colors;
    return SizedBox(
      width: width,
      height: 24,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        onChanged: onChanged,
        style: TextStyle(
          fontFamily: 'Consolas',
          fontSize: 11,
          color: c.foreground,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          hintText: hintText,
          hintStyle: TextStyle(fontSize: 11, color: c.muted),
          filled: true,
          fillColor: c.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: c.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: c.primary),
          ),
        ),
      ),
    );
  }
}
