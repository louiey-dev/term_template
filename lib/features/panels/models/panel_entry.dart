import 'package:flutter/widgets.dart';

/// Defines an individual panel entry displayed in the navigation sidebar.
class PanelEntry {
  const PanelEntry({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    this.isHidden = false,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final bool isHidden;
}

/// Defines a category grouping of [PanelEntry] items.
class PanelGroup {
  const PanelGroup({
    required this.title,
    required this.icon,
    required this.items,
    this.isHidden = false,
  });

  final String title;
  final IconData icon;
  final List<PanelEntry> items;
  final bool isHidden;
}
