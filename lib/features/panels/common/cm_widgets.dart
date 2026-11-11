import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/my_button.dart';
import '../../../shared/my_panel.dart';
import '../../../shared/my_utils.dart';
import '../../../shared/my_widget.dart';

/// State model for preserving interactive widget states across panel navigation.
class CmWidgetsState {
  final bool toggleValue;
  final String dropdownValue;
  final double progressValue;

  const CmWidgetsState({
    this.toggleValue = false,
    this.dropdownValue = 'buildDropdown',
    this.progressValue = 0.65,
  });

  CmWidgetsState copyWith({
    bool? toggleValue,
    String? dropdownValue,
    double? progressValue,
  }) {
    return CmWidgetsState(
      toggleValue: toggleValue ?? this.toggleValue,
      dropdownValue: dropdownValue ?? this.dropdownValue,
      progressValue: progressValue ?? this.progressValue,
    );
  }
}

/// Riverpod provider preserving [CmWidgetsPanel] state across routes.
final cmWidgetsStateProvider = StateProvider<CmWidgetsState>(
  (ref) => const CmWidgetsState(),
);

/// Reference catalog panel showcasing all shared custom widgets and helpers
/// labeled with their names, source files, and usage examples.
class CmWidgetsPanel extends ConsumerWidget {
  const CmWidgetsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final state = ref.watch(cmWidgetsStateProvider);
    final notifier = ref.read(cmWidgetsStateProvider.notifier);

    return MyPanel(
      icon: Icons.widgets_outlined,
      panelTitle: 'Widgets',
      panelSubtitle:
          'Shared widget catalog and usage reference (my_button, my_panel, my_widget)',
      panelActions: [
        PanelActionButton(
          icon: Icons.refresh,
          label: 'Reset State',
          tooltipStr: 'Reset interactive widget demo states',
          onPressed: () => notifier.state = const CmWidgetsState(),
        ),
      ],
      children: [
        // 1. Buttons (lib/shared/my_button.dart)
        MyPanelBody(
          icon: Icons.smart_button,
          title: 'Buttons (lib/shared/my_button.dart)',
          subtitle: 'Action and stateful toggle buttons for headers & bodies',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WidgetReferenceBlock(
                name: 'PanelActionButton',
                signature:
                    'PanelActionButton({required icon, required label, iconColor, onPressed, tooltipStr})',
                description:
                    'Stateless outlined button with icon + label; collapses to icon-only when width < 64px.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PanelActionButton(
                      icon: Icons.touch_app,
                      label: 'PanelActionButton',
                      tooltipStr: 'PanelActionButton tooltip',
                      onPressed: () =>
                          m.showSnackbar(context, 'PanelActionButton pressed'),
                    ),
                    PanelActionButton(
                      icon: Icons.play_arrow,
                      iconColor: c.success,
                      label: 'With iconColor',
                      tooltipStr: 'Custom iconColor sample',
                      onPressed: () =>
                          m.showSnackbar(context, 'Custom iconColor pressed'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 16),
              _WidgetReferenceBlock(
                name: 'PanelToggleButton',
                signature:
                    'PanelToggleButton({required icon, required label, initialValue, onToggle, tooltipStr})',
                description:
                    'Stateful toggle button that highlights with primary background when active.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PanelToggleButton(
                      key: ValueKey(state.toggleValue),
                      icon: Icons.bolt,
                      label: 'PanelToggleButton',
                      tooltipStr: 'Click to toggle active state',
                      initialValue: state.toggleValue,
                      onToggle: (val) {
                        notifier.state = state.copyWith(toggleValue: val);
                      },
                    ),
                    StatusBadge(
                      label: state.toggleValue
                          ? 'ACTIVE: TRUE'
                          : 'ACTIVE: FALSE',
                      color: state.toggleValue ? c.success : c.muted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. Panel Layout Containers (lib/shared/my_panel.dart)
        MyPanelBody(
          icon: Icons.dashboard_outlined,
          title: 'Panel Containers (lib/shared/my_panel.dart)',
          subtitle: 'Structural building blocks for feature panels',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelHierarchyDiagram(colors: c),
              const SizedBox(height: 16),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 16),
              _WidgetReferenceBlock(
                name: 'PanelHeader',
                signature:
                    'PanelHeader({required icon, required iconColor, required title, required subtitle, actions})',
                description:
                    'Top header row displaying an icon, selectable title/subtitle, and trailing action widgets.',
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.background.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: c.border),
                  ),
                  child: PanelHeader(
                    icon: Icons.web_asset,
                    iconColor: c.primary,
                    title: 'PanelHeader',
                    subtitle: 'Subtitle text inside PanelHeader',
                    actions: [
                      PanelActionButton(
                        icon: Icons.code,
                        label: 'PanelActionButton',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 16),
              _WidgetReferenceBlock(
                name: 'PanelBody',
                signature: 'PanelBody({children = const []})',
                description:
                    'Generic bordered surface card container with 16px padding and vertical Column layout.',
                child: PanelBody(
                  children: [
                    Text(
                      'PanelBody',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Raw card container without a built-in header row. Useful for custom card layouts.',
                      style: TextStyle(fontSize: 11, color: c.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 16),
              _WidgetReferenceBlock(
                name: 'MyPanelBody',
                signature:
                    'MyPanelBody({required title, icon, subtitle, trailing, required child})',
                description:
                    'Titled section card wrapping PanelBody with an icon, title, optional subtitle, trailing widget, and child.',
                child: MyPanelBody(
                  icon: Icons.view_agenda_outlined,
                  title: 'MyPanelBody',
                  subtitle: 'Optional subtitle on MyPanelBody',
                  trailing: StatusBadge(label: 'TRAILING', color: c.primary),
                  child: Text(
                    'Child content area inside MyPanelBody.',
                    style: TextStyle(fontSize: 12, color: c.foreground),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 16),
              _WidgetReferenceBlock(
                name: 'MyPanel',
                signature:
                    'MyPanel({required panelTitle, required panelSubtitle, required panelActions, required children, spacing = 10, icon})',
                description:
                    'Root scrollable page wrapper combining a PanelHeader and spaced section widgets.',
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.background.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: c.border),
                  ),
                  child: MyPanel(
                    icon: Icons.layers_outlined,
                    panelTitle: 'MyPanel',
                    panelSubtitle: 'Nested preview of MyPanel structure',
                    panelActions: [
                      StatusBadge(label: 'ACTION SLOT', color: c.muted),
                    ],
                    children: [
                      PanelBody(
                        children: [
                          Text(
                            'Child card inside MyPanel.children',
                            style: TextStyle(fontSize: 11, color: c.muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. Shared UI Widgets & Helpers (lib/shared/my_widget.dart)
        MyPanelBody(
          icon: Icons.extension_outlined,
          title: 'Shared Widgets & Helpers (lib/shared/my_widget.dart)',
          subtitle:
              'Dropdowns, dividers, badges, telemetry tiles, and progress bars',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WidgetReferenceBlock(
                name: 'buildDropdown',
                signature:
                    'buildDropdown<T>(context, {value, hint, required items, onChanged, width = 100})',
                description:
                    'Compact bordered dropdown selector that adapts gracefully to ultra-narrow widths.',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    buildDropdown<String>(
                      context,
                      value: state.dropdownValue,
                      width: 160,
                      items: const [
                        DropdownMenuItem(
                          value: 'buildDropdown',
                          child: Text('buildDropdown'),
                        ),
                        DropdownMenuItem(
                          value: 'Option A',
                          child: Text('Option A'),
                        ),
                        DropdownMenuItem(
                          value: 'Option B',
                          child: Text('Option B'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          notifier.state = state.copyWith(dropdownValue: val);
                        }
                      },
                    ),
                    Text(
                      'Selected: ${state.dropdownValue}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Consolas',
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 16),
              _WidgetReferenceBlock(
                name: 'ToolbarDivider',
                signature: 'const ToolbarDivider()',
                description:
                    'Compact 1x20px vertical separator with 10px horizontal margin for toolbars.',
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(label: 'LEFT ITEM', color: c.muted),
                    const ToolbarDivider(),
                    Text(
                      'ToolbarDivider',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Consolas',
                        color: c.foreground,
                      ),
                    ),
                    const ToolbarDivider(),
                    StatusBadge(label: 'RIGHT ITEM', color: c.muted),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 16),
              _WidgetReferenceBlock(
                name: 'verticalDivider',
                signature:
                    'verticalDivider({color = Colors.grey, thickness = 1, indent = 8, endIndent = 8})',
                description:
                    'Helper returning a Flutter VerticalDivider (place inside a bounded-height Row).',
                child: SizedBox(
                  height: 32,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusBadge(label: 'SECTION A', color: c.muted),
                        const SizedBox(width: 8),
                        verticalDivider(
                          color: c.primary,
                          thickness: 2,
                          indent: 4,
                          endIndent: 4,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'verticalDivider',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Consolas',
                            color: c.foreground,
                          ),
                        ),
                        const SizedBox(width: 8),
                        verticalDivider(
                          color: c.border,
                          thickness: 1,
                          indent: 4,
                          endIndent: 4,
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(label: 'SECTION B', color: c.muted),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 16),
              _WidgetReferenceBlock(
                name: 'StatusBadge',
                signature: 'StatusBadge({required label, required color})',
                description:
                    'Monospace bordered pill badge for displaying connection or telemetry state.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusBadge(label: 'StatusBadge', color: c.primary),
                    StatusBadge(label: 'SUCCESS', color: c.success),
                    StatusBadge(label: 'WARNING', color: c.warning),
                    StatusBadge(label: 'DESTRUCTIVE', color: c.destructive),
                    StatusBadge(label: 'MUTED', color: c.muted),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 16),
              _WidgetReferenceBlock(
                name: 'InfoTile',
                signature:
                    'InfoTile({required label, required value, unit, valueColor, icon, iconColor})',
                description:
                    'Metric readout tile with optional top icon, muted label, large value, and unit.',
                child: Wrap(
                  spacing: 32,
                  runSpacing: 16,
                  children: [
                    InfoTile(
                      icon: Icons.memory,
                      iconColor: c.primary,
                      label: 'InfoTile',
                      value: '42.5',
                      unit: '%',
                      valueColor: c.primary,
                    ),
                    InfoTile(
                      icon: Icons.speed,
                      label: 'Latency',
                      value: '1.8',
                      unit: 'ms',
                      valueColor: c.success,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 16),
              _WidgetReferenceBlock(
                name: 'ProgressBar',
                signature: 'ProgressBar({required value, color, height = 6})',
                description:
                    'Horizontal progress bar taking a normalized value between 0.0 and 1.0.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'ProgressBar (value: ${state.progressValue.toStringAsFixed(2)})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Consolas',
                              color: c.muted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(state.progressValue * 100).round()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Consolas',
                            fontWeight: FontWeight.w600,
                            color: c.foreground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ProgressBar(
                      value: state.progressValue,
                      color: c.primary,
                      height: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PanelHierarchyDiagram extends StatelessWidget {
  const _PanelHierarchyDiagram({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusBadge(label: 'HIERARCHY DIAGRAM', color: c.primary),
            Text(
              'Panel Nesting Structure',
              style: TextStyle(fontSize: 11, color: c.muted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.background.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                'MyMainPanel\n - MyPanel\n  - MyPanelBody\n  - MyPanelBody\n  - MyPanelBody',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Consolas',
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: c.foreground,
                ),
              ),
              const SizedBox(height: 12),
              // Visual nested box diagram
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.surface.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: c.muted.withValues(alpha: 0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MyMainPanel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Consolas',
                        fontWeight: FontWeight.w700,
                        color: c.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: c.primary.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MyPanel (includes PanelHeader)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Consolas',
                              fontWeight: FontWeight.w700,
                              color: c.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: c.card,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: c.border),
                            ),
                            child: Text(
                              'MyPanelBody (wraps PanelBody)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Consolas',
                                fontWeight: FontWeight.w600,
                                color: c.foreground,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: c.card,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: c.border),
                            ),
                            child: Text(
                              'MyPanelBody (wraps PanelBody)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Consolas',
                                fontWeight: FontWeight.w600,
                                color: c.foreground,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: c.card,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: c.border),
                            ),
                            child: Text(
                              'MyPanelBody (wraps PanelBody)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Consolas',
                                fontWeight: FontWeight.w600,
                                color: c.foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WidgetReferenceBlock extends StatelessWidget {
  const _WidgetReferenceBlock({
    required this.name,
    required this.signature,
    required this.description,
    required this.child,
  });

  final String name;
  final String signature;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusBadge(label: name, color: c.primary),
            SelectableText(
              signature,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Consolas',
                color: c.foreground.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(description, style: TextStyle(fontSize: 11, color: c.muted)),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}
