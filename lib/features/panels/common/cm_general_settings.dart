import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/my_button.dart';
import '../../../shared/my_panel.dart';
import '../../../shared/my_widget.dart';
import 'board_command.dart';

/// Reference sample panel providing standard system status and diagnostic commands.
class CmGeneralSettingsPanel extends ConsumerWidget {
  const CmGeneralSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    PanelActionButton btn(IconData icon, String label, String cmd) =>
        PanelActionButton(
          icon: icon,
          label: label,
          tooltipStr: cmd,
          onPressed: () => sendBoardCommand(ref, context, cmd),
        );

    return MyPanel(
      icon: Icons.settings,
      panelTitle: 'General Settings',
      panelSubtitle: 'Common board configuration shared across all targets',
      panelActions: const [],
      children: [
        MyPanelBody(
          icon: Icons.info_outline,
          title: 'System Info',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              btn(Icons.badge, 'Hostname', 'hostname'),
              btn(Icons.memory, 'Model', 'cat /proc/device-tree/model'),
              btn(Icons.terminal, 'Kernel', 'uname -a'),
              btn(Icons.schedule, 'Uptime', 'uptime -p'),
              btn(Icons.info, 'OS Release', 'cat /etc/os-release'),
            ],
          ),
        ),
        MyPanelBody(
          icon: Icons.language,
          title: 'Locale & Environment',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              btn(Icons.translate, 'Locale', 'locale'),
              btn(Icons.list, 'Environment', 'env'),
              btn(Icons.person, 'Whoami', 'whoami'),
              btn(Icons.terminal, 'Shell', 'echo \$SHELL'),
            ],
          ),
        ),
        MyPanelBody(
          icon: Icons.analytics_outlined,
          title: 'Statistics & Diagnostics',
          subtitle: 'System telemetry and shared component showcase',
          trailing: StatusBadge(label: 'MONITORING', color: c.success),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Controls & StatusBadge samples
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PanelToggleButton(
                    icon: Icons.terminal,
                    label: 'Top',
                    tooltipStr: 'Run top command in interactive mode',
                    onToggle: (enabled) {
                      if (enabled) {
                        sendBoardCommand(ref, context, 'top');
                      } else {
                        sendBoardCommand(ref, context, 'killall top');
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(label: 'ONLINE', color: c.success),
                  StatusBadge(label: 'STANDBY', color: c.warning),
                  StatusBadge(label: 'OFFLINE', color: c.destructive),
                  StatusBadge(label: 'IDLE', color: c.muted),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 16),

              // 2. InfoTile sample metrics
              Text(
                'TELEMETRY METRICS (InfoTile)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: c.muted,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 32,
                runSpacing: 16,
                children: [
                  InfoTile(
                    icon: Icons.memory,
                    label: 'CPU Usage',
                    value: '24',
                    unit: '%',
                    valueColor: c.primary,
                  ),
                  InfoTile(
                    icon: Icons.storage,
                    label: 'Memory Used',
                    value: '3.2',
                    unit: 'GB',
                    valueColor: c.foreground,
                  ),
                  InfoTile(
                    icon: Icons.thermostat,
                    label: 'Board Temp',
                    value: '42.5',
                    unit: '°C',
                    valueColor: c.warning,
                  ),
                  InfoTile(
                    icon: Icons.speed,
                    label: 'Fan Speed',
                    value: '2400',
                    unit: 'RPM',
                    valueColor: c.foreground,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 16),

              // 3. ProgressBar sample resource utilization
              Text(
                'RESOURCE UTILIZATION (ProgressBar)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: c.muted,
                ),
              ),
              const SizedBox(height: 12),
              _buildProgressRow(
                c,
                label: 'CPU Core Load',
                percentage: 35,
                displayValue: '35%',
                color: c.primary,
              ),
              const SizedBox(height: 10),
              _buildProgressRow(
                c,
                label: 'Memory Allocation',
                percentage: 62,
                displayValue: '4.9 / 8.0 GB (62%)',
                color: c.warning,
              ),
              const SizedBox(height: 10),
              _buildProgressRow(
                c,
                label: 'Storage (/dev/root)',
                percentage: 84,
                displayValue: '26.8 / 32.0 GB (84%)',
                color: c.destructive,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressRow(
    AppColors c, {
    required String label,
    required int percentage,
    required String displayValue,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: c.muted),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Consolas',
                fontWeight: FontWeight.w600,
                color: c.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ProgressBar(value: percentage / 100.0, color: color, height: 6),
      ],
    );
  }
}
