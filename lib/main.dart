import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/router/app_router.dart';
import 'core/theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initHive();
  final version = await loadVersion();
  final appTitle = version.isNotEmpty
      ? 'term_template v$version — $_osLabel'
      : 'term_template — $_osLabel';
  await _initWindow(appTitle);
  runApp(ProviderScope(child: TermTemplateApp(appTitle: appTitle)));
}

Future<void> _initHive() async {
  final String hivePath;
  if (!kIsWeb && Platform.isWindows) {
    final appData =
        Platform.environment['APPDATA'] ?? Directory.systemTemp.path;
    hivePath = '$appData\\term_template';
  } else if (!kIsWeb) {
    hivePath = (await getApplicationDocumentsDirectory()).path;
  } else {
    hivePath = '';
  }

  if (hivePath.isNotEmpty) {
    await Directory(hivePath).create(recursive: true);
    Hive.init(hivePath);
  }

  try {
    await Hive.openBox<String>('app_settings');
  } catch (_) {
    if (!Hive.isBoxOpen('app_settings')) {
      try {
        await Hive.openBox<String>('app_settings', bytes: Uint8List(0));
      } catch (_) {}
    }
  }
}

Future<void> _initWindow(String title) async {
  if (kIsWeb) return;
  if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
  try {
    await windowManager.ensureInitialized();
    await windowManager.setTitle(title);
  } catch (_) {
    // Window manager native plugin not compiled or supported on current target
  }
}

String get _osLabel {
  if (kIsWeb) return 'Web';
  return switch (Platform.operatingSystem) {
    'windows' => 'Windows',
    'macos' => 'macOS',
    'linux' => 'Linux',
    'android' => 'Android',
    'ios' => 'iOS',
    _ => Platform.operatingSystem,
  };
}

Future<String> loadVersion() async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final String version = packageInfo.version;
    final String buildNumber = packageInfo.buildNumber;
    return '$version+$buildNumber';
  } catch (_) {
    return '';
  }
}

/// Root widget for the term_template application.
class TermTemplateApp extends ConsumerWidget {
  const TermTemplateApp({super.key, this.appTitle = 'term_template'});

  final String appTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: appTitle,
      theme: themeMode.themeData,
      routerConfig: router,
    );
  }
}
