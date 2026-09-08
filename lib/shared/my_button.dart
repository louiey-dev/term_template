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
    return Tooltip(
      message: tooltipStr ?? '',
      child: SizedBox(
        height: 30,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            side: BorderSide(color: c.border),
            foregroundColor: c.foreground,
            textStyle: const TextStyle(fontSize: 11),
          ),
          icon: Icon(icon, size: 14, color: iconColor),
          label: Text(label),
          onPressed: onPressed,
        ),
      ),
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
    return Tooltip(
      message: widget.tooltipStr ?? '',
      child: SizedBox(
        height: 30,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            side: BorderSide(color: _isToggled ? c.primary : c.border),
            backgroundColor: _isToggled ? c.primary : Colors.transparent,
            foregroundColor: _isToggled ? c.primaryForeground : c.foreground,
            textStyle: const TextStyle(fontSize: 11),
          ),
          icon: Icon(widget.icon, size: 14),
          label: Text(widget.label),
          onPressed: () {
            setState(() => _isToggled = !_isToggled);
            widget.onToggle?.call(_isToggled);
          },
        ),
      ),
    );
  }
}
