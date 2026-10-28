import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../../../shared/my_utils.dart';

const _boxName = 'app_settings';
const _favKey = 'cmd_history_favorites';
const _recentKey = 'cmd_history_recents';
const _maxRecents = 12;

/// Seeded into favorites the first time the panel is opened. Once the user
/// edits favorites (even down to empty) the stored list takes over.
const defaultFavorites = <String>[
  'uname -a',
  'uptime -p',
  'df -h',
  'free -h',
  'dmesg | tail -n 40',
  'ps aux | head -n 20',
];

/// Persisted command history: pinned favorites and a rolling recent list.
class CmdHistoryState {
  final List<String> favorites;
  final List<String> recents;

  const CmdHistoryState({this.favorites = const [], this.recents = const []});

  CmdHistoryState copyWith({List<String>? favorites, List<String>? recents}) =>
      CmdHistoryState(
        favorites: favorites ?? this.favorites,
        recents: recents ?? this.recents,
      );
}

/// Global provider for [CmdHistoryNotifier].
final cmdHistoryNotifierProvider =
    NotifierProvider<CmdHistoryNotifier, CmdHistoryState>(
      CmdHistoryNotifier.new,
    );

/// Manages persisted favorite and recent commands via the `app_settings` Hive box.
class CmdHistoryNotifier extends Notifier<CmdHistoryState> {
  @override
  CmdHistoryState build() {
    if (Hive.isBoxOpen(_boxName)) {
      final box = Hive.box<String>(_boxName);
      return CmdHistoryState(
        favorites: _readList(box, _favKey, defaultFavorites),
        recents: _readList(box, _recentKey, const []),
      );
    }
    return const CmdHistoryState(favorites: defaultFavorites);
  }

  List<String> _readList(Box<String> box, String key, List<String> fallback) {
    final raw = box.get(key);
    if (raw == null || raw.isEmpty) return List.of(fallback);
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (e) {
      m.err('Corrupt cmd history "$key", using fallback: $e');
      return List.of(fallback);
    }
  }

  Future<void> _persist() async {
    if (!Hive.isBoxOpen(_boxName)) return;
    try {
      final box = Hive.box<String>(_boxName);
      await box.put(_favKey, jsonEncode(state.favorites));
      await box.put(_recentKey, jsonEncode(state.recents));
    } catch (e) {
      m.err('Failed to persist cmd history: $e');
    }
  }

  /// Records [cmd] as the most recent, de-duplicating and capping the list.
  void addRecent(String cmd) {
    final t = cmd.trim();
    if (t.isEmpty) return;
    final recents = [t, ...state.recents.where((c) => c != t)];
    if (recents.length > _maxRecents) {
      recents.removeRange(_maxRecents, recents.length);
    }
    state = state.copyWith(recents: recents);
    _persist();
  }

  void pin(String cmd) {
    final t = cmd.trim();
    if (t.isEmpty || state.favorites.contains(t)) return;
    state = state.copyWith(favorites: [...state.favorites, t]);
    _persist();
  }

  void unpin(String cmd) {
    state = state.copyWith(
      favorites: state.favorites.where((c) => c != cmd).toList(),
    );
    _persist();
  }

  void clearRecents() {
    state = state.copyWith(recents: const []);
    _persist();
  }
}
