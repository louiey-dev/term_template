import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Builds a styled, compact dropdown menu for toolbar selectors.
Widget buildDropdown<T>(
  BuildContext context, {
  T? value,
  String? hint,
  required List<DropdownMenuItem<T>> items,
  ValueChanged<T?>? onChanged,
  double width = 100,
}) {
  final c = context.colors;
  final matchingCount = items.where((item) => item.value == value).length;
  final safeValue = matchingCount == 1 ? value : null;

  return Container(
    height: 32,
    width: width,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: c.border),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: safeValue,
        hint: hint != null
            ? Text(hint, style: TextStyle(fontSize: 12, color: c.muted))
            : null,
        isExpanded: true,
        dropdownColor: c.card,
        style: TextStyle(fontSize: 12, color: c.foreground),
        icon: Icon(Icons.expand_more, size: 16, color: c.muted),
        items: items,
        onChanged: onChanged,
      ),
    ),
  );
}

/// A compact 1px vertical divider for toolbars.
class ToolbarDivider extends StatelessWidget {
  const ToolbarDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      width: 1,
      height: 20,
      color: context.colors.border,
    );
  }
}

/// A compact status indicator badge with custom label and color.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontFamily: 'Consolas',
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// A tile for displaying a metric value with an optional icon and unit.
class InfoTile extends StatelessWidget {
  const InfoTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.valueColor,
    this.icon,
    this.iconColor,
  });

  final String label;
  final String value;
  final String? unit;
  final Color? valueColor;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: iconColor ?? c.muted),
          const SizedBox(height: 6),
        ],
        Text(label, style: TextStyle(fontSize: 11, color: c.muted)),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Consolas',
              color: valueColor ?? c.foreground,
            ),
            children: unit != null
                ? [
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: c.muted,
                      ),
                    ),
                  ]
                : null,
          ),
        ),
      ],
    );
  }
}

/// A horizontal bar representing progress (0.0 to 1.0).
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 6,
  });

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color ?? c.primary,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

/// Helper function to create a customized [VerticalDivider].
Widget verticalDivider({
  Color color = Colors.grey,
  double thickness = 1,
  double indent = 8,
  double endIndent = 8,
}) {
  return VerticalDivider(
    color: color,
    thickness: thickness,
    indent: indent,
    endIndent: endIndent,
  );
}
