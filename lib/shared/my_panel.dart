import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';

/// Preserves expanded/collapsed state for [MyPanelBody] sections across panel
/// route navigation. Keys are scoped by `[panelTitle]::[sectionKey]`.
final panelBodyExpandedProvider = StateProvider<Map<String, bool>>(
  (ref) => const {},
);

class _MyPanelScope extends InheritedWidget {
  const _MyPanelScope({required this.panelTitle, required super.child});

  final String panelTitle;

  static String? maybeTitleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MyPanelScope>()?.panelTitle;

  @override
  bool updateShouldNotify(_MyPanelScope oldWidget) =>
      panelTitle != oldWidget.panelTitle;
}

/// Header displayed at the top of a [MyPanel].
class PanelHeader extends StatelessWidget {
  const PanelHeader({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.hasBoundedWidth ? constraints.maxWidth : null;
        final showIcon = maxW == null || maxW >= 48;
        return SizedBox(
          width: maxW,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW ?? double.infinity),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showIcon) ...[
                      Icon(icon, size: 20, color: iconColor),
                      const SizedBox(width: 12),
                    ],
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SelectableText(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: c.foreground,
                            ),
                          ),
                          SelectableText(
                            subtitle,
                            style: TextStyle(fontSize: 11, color: c.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (actions.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Generic card container for panel sections.
class PanelBody extends StatelessWidget {
  const PanelBody({super.key, this.children = const []});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Root widget for all feature panels. Combines a [PanelHeader] with section cards.
class MyPanel extends StatelessWidget {
  const MyPanel({
    super.key,
    required this.panelTitle,
    required this.panelSubtitle,
    required this.panelActions,
    required this.children,
    this.spacing = 10,
    this.icon,
  });

  final String panelTitle;
  final String panelSubtitle;
  final List<Widget>? panelActions;
  final List<Widget> children;
  final double spacing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spaced = <Widget>[
      PanelHeader(
        icon: icon ?? Icons.settings,
        iconColor: c.primary,
        title: panelTitle,
        subtitle: panelSubtitle,
        actions: [...?panelActions],
      ),
      const SizedBox(height: 24),
      for (int i = 0; i < children.length; i++) ...[
        children[i],
        if (i < children.length - 1) SizedBox(height: spacing),
      ],
    ];
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: spaced,
    );
    return _MyPanelScope(
      panelTitle: panelTitle,
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.hasBoundedHeight
            ? SingleChildScrollView(child: content)
            : content,
      ),
    );
  }
}

/// A titled card section inside a [MyPanel] with an icon, title, subtitle,
/// optional trailing action, and collapsible body content.
class MyPanelBody extends ConsumerWidget {
  const MyPanelBody({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.trailing,
    required this.child,
    this.collapsible = true,
    this.initiallyExpanded = true,
    this.stateKey,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final bool collapsible;
  final bool initiallyExpanded;
  final String? stateKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final scopeTitle = _MyPanelScope.maybeTitleOf(context) ?? '';
    final sectionKey = '$scopeTitle::${stateKey ?? title}';
    final isExpanded = collapsible
        ? ref.watch(
            panelBodyExpandedProvider.select(
              (map) => map[sectionKey] ?? initiallyExpanded,
            ),
          )
        : true;

    void toggleExpanded() {
      final current = ref.read(panelBodyExpandedProvider);
      ref.read(panelBodyExpandedProvider.notifier).state = {
        ...current,
        sectionKey: !isExpanded,
      };
    }

    final header = LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.hasBoundedWidth ? constraints.maxWidth : null;
        final showIcon = icon != null && (maxW == null || maxW >= 40);
        final showTrailing = trailing != null && (maxW == null || maxW >= 48);
        final showChevron = collapsible && (maxW == null || maxW >= 32);

        final titleStyle = TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: c.foreground,
        );
        final subtitleStyle = TextStyle(fontSize: 11, color: c.muted);

        return SizedBox(
          width: maxW,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW ?? double.infinity),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showIcon) ...[
                      Icon(icon, size: 16, color: c.primary),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          collapsible
                              ? Text(title, style: titleStyle)
                              : SelectableText(title, style: titleStyle),
                          if (subtitle != null)
                            collapsible
                                ? Text(subtitle!, style: subtitleStyle)
                                : SelectableText(
                                    subtitle!,
                                    style: subtitleStyle,
                                  ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (showTrailing || showChevron)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (showTrailing) trailing!,
                    if (showChevron)
                      AnimatedRotation(
                        turns: isExpanded ? 0.0 : -0.25,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        child: Icon(
                          Icons.expand_more,
                          size: 16,
                          color: c.muted,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );

    return PanelBody(
      children: [
        if (collapsible)
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: toggleExpanded,
              borderRadius: BorderRadius.circular(4),
              child: header,
            ),
          )
        else
          header,
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [const SizedBox(height: 14), child],
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
