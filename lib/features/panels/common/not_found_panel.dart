import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Fallback panel shown when an unrecognized panel ID is requested.
class NotFoundPanel extends StatelessWidget {
  const NotFoundPanel({super.key, required this.panelId});

  final String panelId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 40, color: c.muted),
          const SizedBox(height: 12),
          Text(
            'Panel "$panelId" not found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This panel is not registered in the panel registry.',
            style: TextStyle(fontSize: 12, color: c.muted),
          ),
        ],
      ),
    );
  }
}
