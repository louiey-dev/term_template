import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

/// Stored SSH credentials for quick host connection.
class TerminalCredentials {
  final String ip;
  final String id;
  final String password;

  const TerminalCredentials({this.ip = '', this.id = '', this.password = ''});

  TerminalCredentials copyWith({String? ip, String? id, String? password}) {
    return TerminalCredentials(
      ip: ip ?? this.ip,
      id: id ?? this.id,
      password: password ?? this.password,
    );
  }
}

/// Global provider for [TerminalCredentialsNotifier].
final terminalCredentialsNotifierProvider =
    NotifierProvider<TerminalCredentialsNotifier, TerminalCredentials>(
      TerminalCredentialsNotifier.new,
    );

/// Manages and persists SSH credentials in Hive.
class TerminalCredentialsNotifier extends Notifier<TerminalCredentials> {
  static const _boxName = 'app_settings';
  static const _ipKey = 'ssh_ip';
  static const _idKey = 'ssh_id';
  static const _passKey = 'ssh_password';

  @override
  TerminalCredentials build() {
    if (Hive.isBoxOpen(_boxName)) {
      final box = Hive.box<String>(_boxName);
      return TerminalCredentials(
        ip: box.get(_ipKey, defaultValue: '') ?? '',
        id: box.get(_idKey, defaultValue: '') ?? '',
        password: box.get(_passKey, defaultValue: '') ?? '',
      );
    }
    return const TerminalCredentials();
  }

  void updateIp(String value) {
    state = state.copyWith(ip: value);
    _save(_ipKey, value);
  }

  void updateId(String value) {
    state = state.copyWith(id: value);
    _save(_idKey, value);
  }

  void updatePassword(String value) {
    state = state.copyWith(password: value);
    _save(_passKey, value);
  }

  void _save(String key, String val) {
    if (Hive.isBoxOpen(_boxName)) {
      Hive.box<String>(_boxName).put(key, val);
    }
  }
}
