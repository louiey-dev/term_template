import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_split_view/multi_split_view.dart';

import '../../core/theme/app_theme.dart';
import '../connection/providers/serial_pane_provider.dart';
import '../connection/widgets/connection_bar.dart';
import '../terminal/models/terminal_tab.dart';
import '../terminal/providers/terminal_instances.dart';
import '../terminal/widgets/log_panel.dart';
import 'widgets/menu_sidebar.dart';

/// Main scaffold featuring top [ConnectionBar], collapsible [MenuSidebar],
/// routed content, and bottom resizable [LogPanel].
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final MultiSplitViewController _splitController;
  double _lastMainFlex = 3.0;
  double _lastLogFlex = 1.0;
  bool _updatingAreas = false;

  @override
  void initState() {
    super.initState();
    final (mainFlex, logFlex) = TerminalLayoutPersistence.readVerticalFlex();
    _lastMainFlex = mainFlex;
    _lastLogFlex = logFlex;
    final isTermFolded = ref.read(terminalFoldedProvider);
    final isMainFolded = ref.read(mainPanelFoldedProvider);

    final initialAreas = isTermFolded
        ? [
            Area(flex: 1, id: 'main'),
            Area(size: 32, id: 'log'),
          ]
        : isMainFolded
        ? [
            Area(size: 32, id: 'main'),
            Area(flex: 1, id: 'log'),
          ]
        : [
            Area(flex: _lastMainFlex, id: 'main'),
            Area(flex: _lastLogFlex, id: 'log'),
          ];

    _splitController = MultiSplitViewController(areas: initialAreas);
    _splitController.addListener(_onSplitChange);
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _splitController.removeListener(_onSplitChange);
    _splitController.dispose();
    super.dispose();
  }

  void _saveFlexIfUnfolded() {
    final areas = _splitController.areas;
    if (areas.length == 2 &&
        areas[0].flex != null &&
        areas[0].flex! > 0 &&
        areas[1].flex != null &&
        areas[1].flex! > 0) {
      _lastMainFlex = areas[0].flex!;
      _lastLogFlex = areas[1].flex!;
      TerminalLayoutPersistence.saveVerticalFlex(_lastMainFlex, _lastLogFlex);
    }
  }

  void _setAreas(List<Area> areas) {
    _updatingAreas = true;
    try {
      _splitController.areas = areas;
    } finally {
      _updatingAreas = false;
    }
  }

  void _onSplitChange() {
    if (_updatingAreas) return;
    final isTermFolded = ref.read(terminalFoldedProvider);
    if (isTermFolded) {
      for (final a in _splitController.areas) {
        if (a.id == 'log') {
          if ((a.size != null && a.size! > 45) || a.flex != null) {
            ref.read(terminalFoldedProvider.notifier).state = false;
          }
          break;
        }
      }
    }
    final isMainFolded = ref.read(mainPanelFoldedProvider);
    if (isMainFolded) {
      for (final a in _splitController.areas) {
        if (a.id == 'main') {
          if ((a.size != null && a.size! > 45) || a.flex != null) {
            ref.read(mainPanelFoldedProvider.notifier).state = false;
          }
          break;
        }
      }
    }
    if (!ref.read(terminalFoldedProvider) &&
        !ref.read(mainPanelFoldedProvider)) {
      _saveFlexIfUnfolded();
    }
  }

  /// Alt+1..9 jumps focus to the Nth terminal pane.
  /// Alt+T toggles terminal fold/unfold.
  /// Alt+M toggles main panel fold/unfold.
  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!HardwareKeyboard.instance.isAltPressed) return false;

    if (event.logicalKey == LogicalKeyboardKey.keyT) {
      final notifier = ref.read(terminalFoldedProvider.notifier);
      final next = !notifier.state;
      if (next && ref.read(mainPanelFoldedProvider)) {
        ref.read(mainPanelFoldedProvider.notifier).state = false;
      }
      notifier.state = next;
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyM) {
      final notifier = ref.read(mainPanelFoldedProvider.notifier);
      final next = !notifier.state;
      if (next && ref.read(terminalFoldedProvider)) {
        ref.read(terminalFoldedProvider.notifier).state = false;
      }
      notifier.state = next;
      return true;
    }

    final index = _digitIndex(event.logicalKey);
    if (index == null) return false;

    final tabs = ref.read(terminalTabsNotifierProvider);
    if (index >= tabs.length) return false;

    final tab = tabs[index];
    ref.read(activeTabIdProvider.notifier).setActive(tab.id);
    if (tab.type == TerminalTabType.serial) {
      ref.read(serialActiveTabIdProvider.notifier).state = tab.id;
    }
    tab.focusNode.requestFocus();
    return true;
  }

  int? _digitIndex(LogicalKeyboardKey key) {
    const digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    const numpad = [
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
      LogicalKeyboardKey.numpad7,
      LogicalKeyboardKey.numpad8,
      LogicalKeyboardKey.numpad9,
    ];
    final i = digits.indexOf(key);
    if (i != -1) return i;
    final n = numpad.indexOf(key);
    return n != -1 ? n : null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isMainFolded = ref.watch(mainPanelFoldedProvider);

    ref.listen<bool>(terminalFoldedProvider, (prev, isFolded) {
      if (isFolded) {
        _saveFlexIfUnfolded();
        if (ref.read(mainPanelFoldedProvider)) {
          ref.read(mainPanelFoldedProvider.notifier).state = false;
        }
        _setAreas([
          Area(flex: 1, id: 'main'),
          Area(size: 32, id: 'log'),
        ]);
      } else if (!ref.read(mainPanelFoldedProvider)) {
        _setAreas([
          Area(flex: _lastMainFlex, id: 'main'),
          Area(flex: _lastLogFlex, id: 'log'),
        ]);
      }
    });

    ref.listen<bool>(mainPanelFoldedProvider, (prev, isFolded) {
      if (isFolded) {
        _saveFlexIfUnfolded();
        if (ref.read(terminalFoldedProvider)) {
          ref.read(terminalFoldedProvider.notifier).state = false;
        }
        _setAreas([
          Area(size: 32, id: 'main'),
          Area(flex: 1, id: 'log'),
        ]);
      } else if (!ref.read(terminalFoldedProvider)) {
        _setAreas([
          Area(flex: _lastMainFlex, id: 'main'),
          Area(flex: _lastLogFlex, id: 'log'),
        ]);
      }
    });

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          const ConnectionBar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const minWidth = 700.0;
                const minHeight = 452.0;
                final w = constraints.maxWidth < minWidth
                    ? minWidth
                    : constraints.maxWidth;
                final h = constraints.maxHeight < minHeight
                    ? minHeight
                    : constraints.maxHeight;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SizedBox(
                      width: w,
                      height: h,
                      child: MultiSplitViewTheme(
                        data: MultiSplitViewThemeData(
                          dividerThickness: 4,
                          dividerPainter: DividerPainters.background(
                            color: c.border,
                            highlightedColor: c.primary,
                          ),
                        ),
                        child: MultiSplitView(
                          axis: Axis.vertical,
                          controller: _splitController,
                          builder: (context, area) {
                            if (area.id == 'main') {
                              return _buildMainArea(isMainFolded);
                            }
                            return const LogPanel();
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainArea(bool isMainFolded) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        final showCollapsedBar = isMainFolded || maxH <= 40;
        final contentH = maxH < 200.0 ? 200.0 : maxH;

        return Stack(
          fit: StackFit.expand,
          children: [
            Offstage(
              offstage: showCollapsedBar,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minHeight: contentH,
                  maxHeight: contentH,
                  child: Row(
                    children: [
                      const MenuSidebar(),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: widget.child,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (showCollapsedBar && maxH > 0)
              ClipRect(
                child: SizedBox(
                  height: maxH,
                  child: const _MainFoldedBar(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MainFoldedBar extends ConsumerWidget {
  const _MainFoldedBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final foldNotifier = ref.read(mainPanelFoldedProvider.notifier);

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          const minBarW = 300.0;
          final effectiveW = maxW < minBarW ? minBarW : maxW;

          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: effectiveW,
              maxWidth: effectiveW,
              minHeight: 32,
              maxHeight: 32,
              child: SizedBox(
                width: effectiveW,
                height: 32,
                child: Row(
                  children: [
                    Tooltip(
                      message: 'Expand Main Panel (Alt+M)',
                      child: InkWell(
                        onTap: () => foldNotifier.state = false,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: c.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => foldNotifier.state = false,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.dashboard_customize,
                              size: 13,
                              color: c.muted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'MAIN PANEL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: c.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
