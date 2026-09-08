import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'terminal_instances.dart';

/// Configuration for delaying characters and lines during terminal pastes.
class PasteSettings {
  const PasteSettings({this.charDelayMs = 0, this.lineDelayMs = 0});

  final int charDelayMs;
  final int lineDelayMs;

  PasteSettings copyWith({int? charDelayMs, int? lineDelayMs}) {
    return PasteSettings(
      charDelayMs: charDelayMs ?? this.charDelayMs,
      lineDelayMs: lineDelayMs ?? this.lineDelayMs,
    );
  }

  bool get hasDelay => charDelayMs > 0 || lineDelayMs > 0;

  String get label {
    if (!hasDelay) return 'Paste Delay: Off';
    final parts = <String>[];
    if (charDelayMs > 0) parts.add('${charDelayMs}ms/char');
    if (lineDelayMs > 0) parts.add('${lineDelayMs}ms/line');
    return 'Paste Delay: ${parts.join(', ')}';
  }
}

/// Global provider for [PasteSettingsNotifier].
final pasteSettingsNotifierProvider =
    NotifierProvider<PasteSettingsNotifier, PasteSettings>(
      PasteSettingsNotifier.new,
    );

/// Manages paste pacing delay settings to prevent hardware input overflow.
class PasteSettingsNotifier extends Notifier<PasteSettings> {
  static const _boxName = 'app_settings';
  static const _charKey = 'paste_char_delay_ms';
  static const _lineKey = 'paste_line_delay_ms';

  @override
  PasteSettings build() {
    int charDelay = 0;
    int lineDelay = 0;
    if (Hive.isBoxOpen(_boxName)) {
      final box = Hive.box<String>(_boxName);
      charDelay = int.tryParse(box.get(_charKey) ?? '0') ?? 0;
      lineDelay = int.tryParse(box.get(_lineKey) ?? '0') ?? 0;
    }
    return PasteSettings(charDelayMs: charDelay, lineDelayMs: lineDelay);
  }

  void updateCharDelay(int charDelayMs) {
    state = state.copyWith(charDelayMs: charDelayMs);
    _saveToHive();
    _applyToActiveTerminals();
  }

  void updateLineDelay(int lineDelayMs) {
    state = state.copyWith(lineDelayMs: lineDelayMs);
    _saveToHive();
    _applyToActiveTerminals();
  }

  void setPreset(int charDelayMs, int lineDelayMs) {
    state = PasteSettings(charDelayMs: charDelayMs, lineDelayMs: lineDelayMs);
    _saveToHive();
    _applyToActiveTerminals();
  }

  void _saveToHive() {
    if (Hive.isBoxOpen(_boxName)) {
      final box = Hive.box<String>(_boxName);
      box.put(_charKey, state.charDelayMs.toString());
      box.put(_lineKey, state.lineDelayMs.toString());
    }
  }

  void _applyToActiveTerminals() {
    final tabs = ref.read(terminalTabsNotifierProvider);
    for (final tab in tabs) {
      tab.setPasteDelay(state.charDelayMs, state.lineDelayMs);
    }
  }
}
