import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

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
        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: iconColor),
                  const SizedBox(width: 12),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: spaced,
    );
  }
}

/// A titled card section inside a [MyPanel] with an icon, title, subtitle,
/// optional trailing action, and body content.
class MyPanelBody extends StatelessWidget {
  const MyPanelBody({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PanelBody(
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: c.primary),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.foreground,
                    ),
                  ),
                  if (subtitle != null)
                    SelectableText(
                      subtitle!,
                      style: TextStyle(fontSize: 11, color: c.muted),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}
