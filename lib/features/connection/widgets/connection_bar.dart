import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_info_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/my_widget.dart';
import '../../terminal/providers/terminal_instances.dart';
import '../models/serial_config.dart';
import '../providers/serial_config_notifier.dart';
import '../providers/serial_pane_provider.dart';

const int _customBaudRateValue = -1;

/// Indicates whether the top [ConnectionBar] is folded/collapsed vertically.
final connectionBarFoldedProvider = StateProvider<bool>((ref) => false);

enum _AppMenuAction { comSettings, about }

enum _BarSlot { left, right }

class _ConnectionBarLayoutDelegate extends MultiChildLayoutDelegate {
  @override
  void performLayout(Size size) {
    var leftSize = Size.zero;
    if (hasChild(_BarSlot.left)) {
      leftSize = layoutChild(
        _BarSlot.left,
        BoxConstraints(
          maxWidth: size.width,
          minHeight: size.height,
          maxHeight: size.height,
        ),
      );
      positionChild(_BarSlot.left, Offset.zero);
    }

    if (hasChild(_BarSlot.right)) {
      final remainingWidth = (size.width - leftSize.width).clamp(
        0.0,
        size.width,
      );
      final rightSize = layoutChild(
        _BarSlot.right,
        BoxConstraints(
          maxWidth: remainingWidth,
          minHeight: size.height,
          maxHeight: size.height,
        ),
      );
      positionChild(_BarSlot.right, Offset(size.width - rightSize.width, 0));
    }
  }

  @override
  bool shouldRelayout(covariant MultiChildLayoutDelegate oldDelegate) => false;
}

/// Top toolbar for serial port scanning, selection, connection control, and theme switching.
class ConnectionBar extends ConsumerWidget {
  const ConnectionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final ports = ref.watch(availablePortsNotifierProvider);
    final isScanning = ref.watch(serialScanLoadingProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Resolve the active SERIAL pane
    final activeId = ref.watch(effectiveActiveSerialTabIdProvider);
    final hasPane = activeId != null;
    final pane = hasPane
        ? ref.watch(serialPaneNotifierProvider(activeId))
        : SerialPaneState(
            config: SerialConfig(
              baudRate: SerialPaneNotifier.getPersistedBaudRate(),
            ),
          );
    final paneN = hasPane
        ? ref.read(serialPaneNotifierProvider(activeId).notifier)
        : null;
    final config = pane.config;
    final isConnected = pane.isConnected;
    final isFolded = ref.watch(connectionBarFoldedProvider);
    final customBauds = ref.watch(customBaudRatesProvider);
    final allBaudRates = {
      ...standardBaudRates,
      ...customBauds,
      if (config.baudRate > 0) config.baudRate,
    }.toList()..sort();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      height: isFolded ? 28 : 48,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: c.card,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomMultiChildLayout(
        delegate: _ConnectionBarLayoutDelegate(),
        children: [
          LayoutId(
            id: _BarSlot.left,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App menu (COM settings / About)
                  _AppMenuButton(
                    activeId: activeId,
                    settingsEnabled: hasPane && !isConnected,
                  ),
                  const SizedBox(width: 12),

                  Icon(Icons.terminal, size: 18, color: c.primary),
                  const SizedBox(width: 8),
                  Text(
                    kProjName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.foreground,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Scan button
                  _ToolbarButton(
                    icon: isScanning ? Icons.hourglass_empty : Icons.search,
                    label: isScanning ? 'Scanning...' : 'Scan',
                    onPressed: (isConnected || isScanning)
                        ? null
                        : () => ref
                              .read(availablePortsNotifierProvider.notifier)
                              .scan(),
                  ),
                  const SizedBox(width: 8),

                  // COM port list
                  buildDropdown<String>(
                    context,
                    value: config.port.isEmpty ? null : config.port,
                    hint: 'Port',
                    items: ports
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(
                              p,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'Consolas',
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (!hasPane || isConnected)
                        ? null
                        : (v) {
                            if (v != null) paneN!.setPort(v);
                          },
                    width: 90,
                  ),

                  const ToolbarDivider(),

                  // Baud rate list
                  buildDropdown<int>(
                    context,
                    value: config.baudRate,
                    items: [
                      ...allBaudRates.map(
                        (b) => DropdownMenuItem(
                          value: b,
                          child: Text(
                            '$b',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Consolas',
                            ),
                          ),
                        ),
                      ),
                      DropdownMenuItem<int>(
                        value: _customBaudRateValue,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 12, color: c.primary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Custom...',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: c.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (!hasPane || isConnected)
                        ? null
                        : (v) {
                            if (v == _customBaudRateValue) {
                              _showCustomBaudRateDialog(
                                context,
                                ref,
                                paneN!,
                                config.baudRate,
                              );
                            } else if (v != null) {
                              paneN!.setBaudRate(v);
                            }
                          },
                    width: 120,
                  ),

                  const ToolbarDivider(),

                  // Connect / Disconnect button
                  SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isConnected
                            ? c.destructive
                            : c.primary,
                        foregroundColor: isConnected
                            ? Colors.white
                            : c.primaryForeground,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: Icon(
                        isConnected ? Icons.link_off : Icons.link,
                        size: 14,
                      ),
                      label: Text(isConnected ? 'Disconnect' : 'Connect'),
                      onPressed: (!hasPane || config.port.isEmpty)
                          ? null
                          : () {
                              if (isConnected) {
                                paneN!.disconnect();
                              } else {
                                paneN!.connect();
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
          LayoutId(
            id: _BarSlot.right,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 8),

                  // Main Panel toggle
                  Tooltip(
                    message: ref.watch(mainPanelFoldedProvider)
                        ? 'Expand main panel (Alt+M)'
                        : 'Fold main panel (Alt+M)',
                    child: IconButton(
                      icon: Icon(
                        Icons.dashboard_customize,
                        size: 18,
                        color: ref.watch(mainPanelFoldedProvider)
                            ? c.muted
                            : c.primary,
                      ),
                      onPressed: () {
                        final notifier = ref.read(
                          mainPanelFoldedProvider.notifier,
                        );
                        notifier.state = !notifier.state;
                      },
                    ),
                  ),

                  const SizedBox(width: 4),

                  // Terminal Panel toggle
                  Tooltip(
                    message: ref.watch(terminalFoldedProvider)
                        ? 'Expand terminal panel (Alt+T)'
                        : 'Fold terminal panel (Alt+T)',
                    child: IconButton(
                      icon: Icon(
                        Icons.terminal,
                        size: 18,
                        color: ref.watch(terminalFoldedProvider)
                            ? c.muted
                            : c.primary,
                      ),
                      onPressed: () {
                        final notifier = ref.read(
                          terminalFoldedProvider.notifier,
                        );
                        notifier.state = !notifier.state;
                      },
                    ),
                  ),

                  const SizedBox(width: 4),

                  // Theme toggle (cycles Dark -> Dark Blue -> Medium -> Green -> Pink -> Yellow Grey -> Light)
                  Tooltip(
                    message:
                        'Theme: ${themeMode.label} (click for ${themeMode.next.label})',
                    child: IconButton(
                      icon: Icon(themeMode.icon, size: 18, color: c.muted),
                      onPressed: () =>
                          ref.read(themeModeProvider.notifier).toggle(),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Status indicator pill
                  _StatusPill(
                    config: config,
                    isConnected: isConnected,
                    hasPane: hasPane,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppMenuButton extends StatelessWidget {
  const _AppMenuButton({required this.activeId, required this.settingsEnabled});

  final String? activeId;
  final bool settingsEnabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopupMenuButton<_AppMenuAction>(
      color: c.card,
      tooltip: 'Menu',
      position: PopupMenuPosition.under,
      onSelected: (action) {
        switch (action) {
          case _AppMenuAction.comSettings:
            final id = activeId;
            if (id != null) {
              showDialog<void>(
                context: context,
                builder: (_) => _ComSettingsDialog(tabId: id),
              );
            }
          case _AppMenuAction.about:
            showDialog<void>(
              context: context,
              builder: (_) => const _AboutDialog(),
            );
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<_AppMenuAction>(
          value: _AppMenuAction.comSettings,
          enabled: settingsEnabled,
          height: 40,
          child: Row(
            children: [
              Icon(
                Icons.tune,
                size: 16,
                color: settingsEnabled ? c.foreground : c.muted,
              ),
              const SizedBox(width: 10),
              Text(
                'COM settings',
                style: TextStyle(
                  fontSize: 13,
                  color: settingsEnabled ? c.foreground : c.muted,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<_AppMenuAction>(
          value: _AppMenuAction.about,
          height: 40,
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: c.foreground),
              const SizedBox(width: 10),
              Text(
                'About',
                style: TextStyle(fontSize: 13, color: c.foreground),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComSettingsDialog extends ConsumerWidget {
  const _ComSettingsDialog({required this.tabId});

  final String tabId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final state = ref.watch(serialPaneNotifierProvider(tabId));
    final notifier = ref.read(serialPaneNotifierProvider(tabId).notifier);
    final config = state.config;
    final locked = state.isConnected;

    return AlertDialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.border),
      ),
      title: Row(
        children: [
          Icon(Icons.tune, size: 18, color: c.primary),
          const SizedBox(width: 8),
          Text(
            'COM Settings',
            style: TextStyle(fontSize: 15, color: c.foreground),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (locked)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Disconnect to change settings.',
                style: TextStyle(fontSize: 11, color: c.warning),
              ),
            ),
          _DialogSectionLabel('Encoding'),
          for (final e in SerialEncoding.values)
            _DialogCheckRow(
              label: e.label,
              selected: config.encoding == e,
              enabled: !locked,
              onTap: () => notifier.setEncoding(e),
            ),
          const SizedBox(height: 8),
          _DialogSectionLabel('New Line'),
          for (final n in NewLine.values)
            _DialogCheckRow(
              label: n.label,
              selected: config.newLine == n,
              enabled: !locked,
              onTap: () => notifier.setNewLine(n),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close', style: TextStyle(color: c.primary)),
        ),
      ],
    );
  }
}

class _DialogSectionLabel extends StatelessWidget {
  const _DialogSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: c.muted,
        ),
      ),
    );
  }
}

class _DialogCheckRow extends StatelessWidget {
  const _DialogCheckRow({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.check,
              size: 16,
              color: selected ? c.primary : Colors.transparent,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: enabled ? c.foreground : c.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutDialog extends ConsumerWidget {
  const _AboutDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final versionAsync = ref.watch(appVersionProvider);
    final version = versionAsync.asData?.value;

    return AlertDialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.border),
      ),
      title: Row(
        children: [
          Icon(Icons.terminal, size: 20, color: c.primary),
          const SizedBox(width: 8),
          Text(
            kAppName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.foreground,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            version != null && version.isNotEmpty
                ? 'Version $version'
                : 'Version ...',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Consolas',
              color: c.muted,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Lightweight Flutter UART/terminal project template based on sanc_term.',
            style: TextStyle(fontSize: 13, color: c.foreground),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close', style: TextStyle(color: c.primary)),
        ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 32,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          side: BorderSide(color: c.border),
          foregroundColor: c.foreground,
          textStyle: const TextStyle(fontSize: 12),
        ),
        icon: Icon(icon, size: 14),
        label: Text(label),
        onPressed: onPressed,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.config,
    required this.isConnected,
    required this.hasPane,
  });

  final SerialConfig config;
  final bool isConnected;
  final bool hasPane;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = isConnected
        ? '${config.port} | ${config.baudRate} | ${config.encoding.label} | ${config.newLine.label}'
        : (hasPane ? 'Disconnected' : 'No serial pane');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? c.primary.withValues(alpha: 0.5) : c.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isConnected ? c.primary : c.muted.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Consolas',
              color: isConnected ? c.primary : c.muted,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showCustomBaudRateDialog(
  BuildContext context,
  WidgetRef ref,
  SerialPaneNotifier paneN,
  int currentBaud,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => Consumer(
      builder: (context, refConsumer, _) {
        final customBauds = refConsumer.watch(customBaudRatesProvider);
        return _CustomBaudRateDialog(
          initialBaud: currentBaud,
          customBauds: customBauds,
          onDeleteCustom: (baud) {
            refConsumer.read(customBaudRatesProvider.notifier).remove(baud);
            if (currentBaud == baud) {
              paneN.setBaudRate(SerialPaneNotifier.defaultBaudRate);
            }
          },
          onConfirm: (baud) {
            refConsumer.read(customBaudRatesProvider.notifier).add(baud);
            paneN.setBaudRate(baud);
          },
        );
      },
    ),
  );
}

class _CustomBaudRateDialog extends StatefulWidget {
  const _CustomBaudRateDialog({
    required this.initialBaud,
    required this.onConfirm,
    this.customBauds = const [],
    this.onDeleteCustom,
  });

  final int initialBaud;
  final ValueChanged<int> onConfirm;
  final List<int> customBauds;
  final ValueChanged<int>? onDeleteCustom;

  @override
  State<_CustomBaudRateDialog> createState() => _CustomBaudRateDialogState();
}

class _CustomBaudRateDialogState extends State<_CustomBaudRateDialog> {
  static const _commonPresets = [
    74880,
    250000,
    500000,
    1000000,
    2000000,
    3000000,
  ];

  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialBaud > 0 ? '${widget.initialBaud}' : '115200',
    );
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    final value = int.tryParse(text);
    if (value == null || value <= 0) {
      setState(() => _error = 'Enter a valid positive number');
      return;
    }
    if (value > 10000000) {
      setState(() => _error = 'Maximum baud rate is 10,000,000');
      return;
    }
    widget.onConfirm(value);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AlertDialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.border),
      ),
      title: Row(
        children: [
          Icon(Icons.speed, size: 18, color: c.primary),
          const SizedBox(width: 8),
          Text(
            'Custom Baud Rate',
            style: TextStyle(fontSize: 15, color: c.foreground),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter custom baud rate (bps):',
                style: TextStyle(fontSize: 12, color: c.muted),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                  fontSize: 13,
                  color: c.foreground,
                  fontFamily: 'Consolas',
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'e.g. 2000000',
                  errorText: _error,
                  filled: true,
                  fillColor: c.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: c.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: c.primary),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              Text(
                'COMMON PRESETS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: c.muted,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _commonPresets.map((p) {
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _controller.text = '$p';
                        _controller.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _controller.text.length,
                        );
                        _error = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: c.border),
                      ),
                      child: Text(
                        '$p',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Consolas',
                          color: c.foreground,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (widget.customBauds.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'SAVED CUSTOM RATES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: c.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.customBauds.map((b) {
                    return Container(
                      padding: const EdgeInsets.only(
                        left: 8,
                        right: 4,
                        top: 2,
                        bottom: 2,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _controller.text = '$b';
                                _controller.selection = TextSelection(
                                  baseOffset: 0,
                                  extentOffset: _controller.text.length,
                                );
                                _error = null;
                              });
                            },
                            child: Text(
                              '$b',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Consolas',
                                color: c.foreground,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => widget.onDeleteCustom?.call(b),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.close,
                                size: 12,
                                color: c.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: c.muted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primary,
            foregroundColor: c.primaryForeground,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: _submit,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
