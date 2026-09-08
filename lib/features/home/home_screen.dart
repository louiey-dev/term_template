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

  @override
  void initState() {
    super.initState();
    _splitController = MultiSplitViewController(
      areas: [
        Area(flex: 3, id: 'main'),
        Area(flex: 1, id: 'log'),
      ],
    );
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

  void _onSplitChange() {
    final isFolded = ref.read(terminalFoldedProvider);
    if (isFolded) {
      for (final a in _splitController.areas) {
        if (a.id == 'log') {
          if ((a.size != null && a.size! > 45) || a.flex != null) {
            ref.read(terminalFoldedProvider.notifier).state = false;
          }
          break;
        }
      }
    }
  }

  /// Alt+1..9 jumps focus to the Nth terminal pane.
  /// Alt+T toggles terminal fold/unfold.
  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!HardwareKeyboard.instance.isAltPressed) return false;

    if (event.logicalKey == LogicalKeyboardKey.keyT) {
      final notifier = ref.read(terminalFoldedProvider.notifier);
      notifier.state = !notifier.state;
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

    ref.listen<bool>(terminalFoldedProvider, (prev, isFolded) {
      if (isFolded) {
        for (final a in _splitController.areas) {
          if (a.id == 'main' && a.flex != null && a.flex! > 0) {
            _lastMainFlex = a.flex!;
          } else if (a.id == 'log' && a.flex != null && a.flex! > 0) {
            _lastLogFlex = a.flex!;
          }
        }
        _splitController.areas = [
          Area(flex: 1, id: 'main'),
          Area(size: 32, id: 'log'),
        ];
      } else {
        _splitController.areas = [
          Area(flex: _lastMainFlex, id: 'main'),
          Area(flex: _lastLogFlex, id: 'log'),
        ];
      }
    });

    return Scaffold(
      backgroundColor: c.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          const minWidth = 700.0;
          const minHeight = 500.0;
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
                child: Column(
                  children: [
                    const ConnectionBar(),
                    Expanded(
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
                              return Row(
                                children: [
                                  const MenuSidebar(),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(24),
                                      child: widget.child,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return const LogPanel();
                          },
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
