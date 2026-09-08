import 'package:flutter/material.dart';

import 'common/cm_general_settings.dart';
import 'models/panel_entry.dart';

/// Registry mapping unique panel IDs to widget factory functions.
final Map<String, Widget Function()> panelRegistry = {
  'cm_general': () => const CmGeneralSettingsPanel(),
};

/// Defined panel navigation groups displayed in the menu sidebar.
final List<PanelGroup> panelGroups = [
  const PanelGroup(
    title: 'COMMON',
    icon: Icons.layers,
    items: [
      PanelEntry(
        id: 'cm_general',
        label: 'General Settings',
        description: 'System info and diagnostic commands',
        icon: Icons.settings,
      ),
    ],
  ),
];

/// Checks whether a panel with [id] is marked as hidden.
bool isPanelHidden(String id) {
  for (final group in panelGroups) {
    if (group.isHidden) {
      for (final item in group.items) {
        if (item.id == id) return true;
      }
    }
    for (final item in group.items) {
      if (item.id == id && item.isHidden) return true;
    }
  }
  return false;
}
