import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Central application display name used across window titles, UI headers, and dialogs.
const kAppName = 'Term Template';

const kProjName = 'term_template';

/// Provides application name.
final appNameProvider = Provider<String>((ref) => kAppName);

/// Provides application version dynamically loaded from pubspec.yaml via [PackageInfo].
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  } catch (_) {
    return '';
  }
});
