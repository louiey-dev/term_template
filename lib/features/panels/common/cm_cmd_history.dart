import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/my_button.dart';
import '../../../shared/my_panel.dart';
import 'board_command.dart';
import 'cmd_history_service.dart';

/// Quick command sender with a recent list and pinnable favorites.
/// Both are persisted via Hive (see [CmdHistoryNotifier]).
class CmCmdHistoryPanel extends ConsumerStatefulWidget {
  const CmCmdHistoryPanel({super.key});

  @override
  ConsumerState<CmCmdHistoryPanel> createState() => _CmCmdHistoryPanelState();
}

/// State model for preserving Command History input text across page transitions
class CmCmdHistoryParamsState {
  final String cmd;

  const CmCmdHistoryParamsState({this.cmd = ''});
}

/// Riverpod provider for persisting Command History input value
final cmCmdHistoryParamsProvider = StateProvider<CmCmdHistoryParamsState>(
  (ref) => const CmCmdHistoryParamsState(),
);

class _CmCmdHistoryPanelState extends ConsumerState<CmCmdHistoryPanel> {
  late final TextEditingController _cmd;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(cmCmdHistoryParamsProvider);
    _cmd = TextEditingController(text: saved.cmd);
    _cmd.addListener(_saveParams);
  }

  void _saveParams() {
    ref.read(cmCmdHistoryParamsProvider.notifier).state =
        CmCmdHistoryParamsState(cmd: _cmd.text);
  }

  @override
  void dispose() {
    _cmd.dispose();
    super.dispose();
  }

  CmdHistoryNotifier get _history =>
      ref.read(cmdHistoryNotifierProvider.notifier);

  void _run(String cmd) {
    final trimmed = cmd.trim();
    if (trimmed.isEmpty) return;
    sendBoardCommand(ref, context, trimmed);
    _history.addRecent(trimmed);
  }

  /// A run button plus a trailing icon (pin to favorite / unpin).
  Widget _commandChip(
    BuildContext context, {
    required String cmd,
    required IconData runIcon,
    required IconData trailingIcon,
    required String trailingTip,
    required VoidCallback onTrailing,
  }) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelActionButton(
          icon: runIcon,
          label: cmd,
          tooltipStr: cmd,
          onPressed: () => _run(cmd),
        ),
        Tooltip(
          message: trailingTip,
          child: SizedBox(
            height: 30,
            width: 30,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 15,
              color: c.muted,
              icon: Icon(trailingIcon),
              onPressed: onTrailing,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final history = ref.watch(cmdHistoryNotifierProvider);
    final favorites = history.favorites;
    final recents = history.recents;
    return MyPanel(
      icon: Icons.history,
      panelTitle: 'Command History',
      panelSubtitle: 'Send commands and reuse recent or favorite ones',
      panelActions: const [],
      children: [
        MyPanelBody(
          icon: Icons.terminal,
          title: 'Send Command',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _cmd,
                    style: const TextStyle(fontFamily: 'Consolas'),
                    decoration: const InputDecoration(
                      hintText: 'Type a command…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: _run,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PanelActionButton(
                icon: Icons.push_pin_outlined,
                label: 'Pin',
                tooltipStr: 'Add this command to favorites',
                onPressed: () => _history.pin(_cmd.text),
              ),
              const SizedBox(width: 8),
              PanelActionButton(
                icon: Icons.send,
                label: 'Send',
                tooltipStr: 'Send command to the active console',
                onPressed: () => _run(_cmd.text),
              ),
            ],
          ),
        ),
        MyPanelBody(
          icon: Icons.star_outline,
          title: 'Favorites',
          subtitle: favorites.isEmpty ? 'No favorites pinned' : null,
          child: favorites.isEmpty
              ? Text(
                  'Pin a command above to keep it here.',
                  style: TextStyle(fontSize: 12, color: c.muted),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in favorites)
                      _commandChip(
                        context,
                        cmd: f,
                        runIcon: Icons.play_arrow,
                        trailingIcon: Icons.close,
                        trailingTip: 'Unpin from favorites',
                        onTrailing: () => _history.unpin(f),
                      ),
                  ],
                ),
        ),
        MyPanelBody(
          icon: Icons.history,
          title: 'Recent',
          subtitle: recents.isEmpty ? 'No commands yet' : null,
          trailing: recents.isEmpty
              ? null
              : PanelActionButton(
                  icon: Icons.clear_all,
                  label: 'Clear',
                  tooltipStr: 'Clear recent list',
                  onPressed: _history.clearRecents,
                ),
          child: recents.isEmpty
              ? Text(
                  'Sent commands will appear here for quick reuse.',
                  style: TextStyle(fontSize: 12, color: c.muted),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in recents)
                      _commandChip(
                        context,
                        cmd: r,
                        runIcon: Icons.replay,
                        trailingIcon: Icons.push_pin_outlined,
                        trailingTip: 'Pin to favorites',
                        onTrailing: () => _history.pin(r),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
