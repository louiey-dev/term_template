import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/my_widget.dart';
import '../../terminal/providers/terminal_instances.dart';
import '../models/serial_config.dart';
import '../providers/serial_config_notifier.dart';
import '../providers/serial_pane_provider.dart';

const _baudRates = [
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

enum _AppMenuAction { comSettings, about }

const _appVersion = '1.0.0';

/// Top toolbar for serial port scanning, selection, connection control, and theme switching.
class ConnectionBar extends ConsumerWidget {
  const ConnectionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final ports = ref.watch(availablePortsNotifierProvider);
    final isScanning = ref.watch(serialScanLoadingProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    // Resolve the active SERIAL pane
    final activeId = ref.watch(effectiveActiveSerialTabIdProvider);
    final hasPane = activeId != null;
    final pane = hasPane
        ? ref.watch(serialPaneNotifierProvider(activeId))
        : const SerialPaneState();
    final paneN = hasPane
        ? ref.read(serialPaneNotifierProvider(activeId).notifier)
        : null;
    final config = pane.config;
    final isConnected = pane.isConnected;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: c.card,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
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
                    'term_template',
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
                    items: _baudRates
                        .map(
                          (b) => DropdownMenuItem(
                            value: b,
                            child: Text(
                              '$b',
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
                            if (v != null) paneN!.setBaudRate(v);
                          },
                    width: 100,
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

          const SizedBox(width: 8),

          // Terminal Panel toggle
          Tooltip(
            message: ref.watch(terminalFoldedProvider)
                ? 'Expand terminal panel (Alt+T)'
                : 'Fold terminal panel (Alt+T)',
            child: IconButton(
              icon: Icon(
                Icons.terminal,
                size: 18,
                color: ref.watch(terminalFoldedProvider) ? c.muted : c.primary,
              ),
              onPressed: () {
                final notifier = ref.read(terminalFoldedProvider.notifier);
                notifier.state = !notifier.state;
              },
            ),
          ),

          const SizedBox(width: 4),

          // Theme toggle
          Tooltip(
            message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            child: IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 18,
                color: c.muted,
              ),
              onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
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

class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

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
          Icon(Icons.terminal, size: 20, color: c.primary),
          const SizedBox(width: 8),
          Text(
            'term_template',
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
            'Version $_appVersion',
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
