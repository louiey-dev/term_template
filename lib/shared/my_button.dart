import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Reusable action button for panel headers and toolbar actions.
class PanelActionButton extends StatelessWidget {
  const PanelActionButton({
    super.key,
    required this.icon,
    this.iconColor,
    required this.label,
    this.onPressed,
    this.tooltipStr = '',
  });

  final IconData icon;
  final Color? iconColor;
  final String label;
  final VoidCallback? onPressed;
  final String? tooltipStr;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.hasBoundedWidth && constraints.maxWidth < 64;
        final style = OutlinedButton.styleFrom(
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 10),
          side: BorderSide(color: c.border),
          foregroundColor: c.foreground,
          textStyle: const TextStyle(fontSize: 11),
        );
        return Tooltip(
          message: tooltipStr?.isNotEmpty == true ? tooltipStr! : label,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 30, maxWidth: 240),
            child: compact
                ? OutlinedButton(
                    style: style,
                    onPressed: onPressed,
                    child: Icon(icon, size: 14, color: iconColor),
                  )
                : OutlinedButton.icon(
                    style: style,
                    icon: Icon(icon, size: 14, color: iconColor),
                    label: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: onPressed,
                  ),
          ),
        );
      },
    );
  }
}

/// A toggle button that visually indicates an active state.
class PanelToggleButton extends StatefulWidget {
  const PanelToggleButton({
    super.key,
    required this.icon,
    required this.label,
    this.tooltipStr,
    this.initialValue = false,
    this.onToggle,
  });

  final IconData icon;
  final String label;
  final String? tooltipStr;
  final bool initialValue;
  final ValueChanged<bool>? onToggle;

  @override
  State<PanelToggleButton> createState() => _PanelToggleButtonState();
}

class _PanelToggleButtonState extends State<PanelToggleButton> {
  late bool _isToggled;

  @override
  void initState() {
    super.initState();
    _isToggled = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.hasBoundedWidth && constraints.maxWidth < 64;
        final style = OutlinedButton.styleFrom(
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 10),
          side: BorderSide(color: _isToggled ? c.primary : c.border),
          backgroundColor: _isToggled ? c.primary : Colors.transparent,
          foregroundColor: _isToggled ? c.primaryForeground : c.foreground,
          textStyle: const TextStyle(fontSize: 11),
        );
        void toggle() {
          setState(() => _isToggled = !_isToggled);
          widget.onToggle?.call(_isToggled);
        }

        return Tooltip(
          message: widget.tooltipStr?.isNotEmpty == true
              ? widget.tooltipStr!
              : widget.label,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 30, maxWidth: 240),
            child: compact
                ? OutlinedButton(
                    style: style,
                    onPressed: toggle,
                    child: Icon(widget.icon, size: 14),
                  )
                : OutlinedButton.icon(
                    style: style,
                    icon: Icon(widget.icon, size: 14),
                    label: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: toggle,
                  ),
          ),
        );
      },
    );
  }
}
