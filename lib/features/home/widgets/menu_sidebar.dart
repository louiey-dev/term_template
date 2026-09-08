import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../panels/models/panel_entry.dart';
import '../../panels/panel_registry.dart';

/// Tracks whether the navigation sidebar is collapsed.
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

/// Collapsible left navigation sidebar displaying grouped panel entries.
class MenuSidebar extends ConsumerWidget {
  const MenuSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final isCollapsed = ref.watch(sidebarCollapsedProvider);
    final location = GoRouterState.of(context).uri.toString();
    final activePanelId = location.startsWith('/home/panel/')
        ? location.substring('/home/panel/'.length)
        : null;

    final visibleGroups = panelGroups
        .map((group) {
          final visibleItems = group.items
              .where((item) => !item.isHidden)
              .toList();
          return PanelGroup(
            title: group.title,
            icon: group.icon,
            items: visibleItems,
            isHidden: group.isHidden,
          );
        })
        .where((group) => group.items.isNotEmpty)
        .toList();

    final hasAnyActiveGroup = visibleGroups.any(
      (group) => group.items.any((e) => e.id == activePanelId),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: isCollapsed ? 52 : 220,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: c.sidebar,
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: Column(
        children: [
          // Sidebar Fold / Unfold Toggle Header
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: c.border.withValues(alpha: 0.5)),
              ),
            ),
            child: isCollapsed
                ? Center(
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right, size: 18),
                      color: c.muted,
                      tooltip: 'Expand Sidebar',
                      onPressed: () {
                        ref.read(sidebarCollapsedProvider.notifier).state =
                            false;
                      },
                    ),
                  )
                : ClipRect(
                    child: OverflowBox(
                      minWidth: 212,
                      maxWidth: 212,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 212,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.dashboard_customize,
                                  size: 14,
                                  color: c.muted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'PANELS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    color: c.muted,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_left, size: 18),
                              color: c.muted,
                              tooltip: 'Fold Sidebar',
                              onPressed: () {
                                ref
                                        .read(sidebarCollapsedProvider.notifier)
                                        .state =
                                    true;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),

          // Menu List View
          Expanded(
            child: isCollapsed
                ? _buildCollapsedListView(
                    context,
                    visibleGroups,
                    activePanelId,
                    c,
                  )
                : _buildExpandedListView(
                    context,
                    visibleGroups,
                    activePanelId,
                    hasAnyActiveGroup,
                    c,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedListView(
    BuildContext context,
    List<PanelGroup> visibleGroups,
    String? activePanelId,
    bool hasAnyActiveGroup,
    AppColors c,
  ) {
    return ClipRect(
      child: OverflowBox(
        minWidth: 220,
        maxWidth: 220,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 220,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: visibleGroups.length,
            itemBuilder: (context, groupIndex) {
              final group = visibleGroups[groupIndex];
              final isGroupActive = group.items.any(
                (e) => e.id == activePanelId,
              );
              final shouldExpand =
                  isGroupActive || (!hasAnyActiveGroup && groupIndex == 0);

              return Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: PageStorageKey('group_${group.title}'),
                  initiallyExpanded: shouldExpand,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
                  collapsedIconColor: isGroupActive ? c.primary : c.muted,
                  iconColor: isGroupActive ? c.primary : c.muted,
                  title: Row(
                    children: [
                      Icon(
                        group.icon,
                        size: 14,
                        color: isGroupActive ? c.primary : c.muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          group.title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isGroupActive ? c.primary : c.muted,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  children: group.items
                      .map(
                        (entry) => _SideMenuItem(
                          entry: entry,
                          isActive: entry.id == activePanelId,
                          onTap: () => context.go('/home/panel/${entry.id}'),
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedListView(
    BuildContext context,
    List<PanelGroup> visibleGroups,
    String? activePanelId,
    AppColors c,
  ) {
    return ClipRect(
      child: OverflowBox(
        minWidth: 52,
        maxWidth: 52,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 52,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            itemCount: visibleGroups.length,
            itemBuilder: (context, groupIndex) {
              final group = visibleGroups[groupIndex];

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Tooltip(
                      message: group.title,
                      child: Icon(group.icon, size: 14, color: c.muted),
                    ),
                  ),
                  for (final entry in group.items) ...[
                    _CollapsedSideMenuItem(
                      entry: entry,
                      isActive: entry.id == activePanelId,
                      onTap: () => context.go('/home/panel/${entry.id}'),
                    ),
                    const SizedBox(height: 4),
                  ],
                  const Divider(height: 12, indent: 6, endIndent: 6),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CollapsedSideMenuItem extends StatelessWidget {
  const _CollapsedSideMenuItem({
    required this.entry,
    required this.isActive,
    required this.onTap,
  });

  final PanelEntry entry;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: '${entry.label}\n${entry.description}',
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isActive ? c.primary : c.surface,
              borderRadius: BorderRadius.circular(6),
              border: isActive
                  ? Border.all(color: c.primaryForeground, width: 1.5)
                  : null,
            ),
            child: Icon(
              entry.icon,
              size: 18,
              color: isActive ? c.primaryForeground : c.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _SideMenuItem extends StatelessWidget {
  const _SideMenuItem({
    required this.entry,
    required this.isActive,
    required this.onTap,
  });

  final PanelEntry entry;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? c.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive ? c.primary : c.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    entry.icon,
                    size: 16,
                    color: isActive ? c.primaryForeground : c.muted,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? c.foreground
                              : c.foreground.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.description,
                        style: TextStyle(fontSize: 9, color: c.muted),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: c.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
