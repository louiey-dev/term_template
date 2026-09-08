import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../core/theme/app_theme.dart';

/// Global singleton instance for convenient utility access.
final MyUtils m = MyUtils();

/// General helper utilities for logging, snackbars, and byte conversions.
class MyUtils {
  /// Shows a success SnackBar with the primary theme color.
  void showSnackbar(BuildContext context, String msg, {int durationMs = 1000}) {
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: Duration(milliseconds: durationMs),
        content: Text(msg),
        backgroundColor: c.primary,
        action: SnackBarAction(
          label: 'OK',
          textColor: c.primaryForeground,
          onPressed: () {},
        ),
      ),
    );
  }

  /// Shows an error SnackBar with the destructive theme color.
  void showErrorSnackbar(
    BuildContext context,
    String msg, {
    int durationMs = 2000,
  }) {
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: Duration(milliseconds: durationMs),
        content: Text(msg),
        backgroundColor: c.destructive,
        action: SnackBarAction(
          label: 'OK',
          textColor: c.foreground,
          onPressed: () {},
        ),
      ),
    );
  }

  /// Prints a standard debug message to console in debug mode.
  void log(String msg) {
    if (kDebugMode) {
      debugPrint(msg);
    }
  }

  /// Prints a debug-tagged message to console in debug mode.
  void dbg(String msg) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $msg');
    }
  }

  /// Prints an error message to console with [ERROR] prefix.
  void err(String msg) {
    if (kDebugMode) {
      debugPrint('[ERROR] $msg');
    }
  }

  /// Decodes a list of UTF-8 byte integers into a String.
  String listIntToString(List<int> list) {
    return utf8.decode(list, allowMalformed: true);
  }

  /// Encodes a String into a list of Uint8List byte chunks.
  List<Uint8List> stringToUint8ListList(String str) {
    List<int> list = utf8.encode(str);
    return [Uint8List.fromList(list)];
  }

  /// Encodes a String into a Uint8List byte array.
  Uint8List stringToUint8List(String str) {
    return Uint8List.fromList(utf8.encode(str));
  }

  /// Decodes a Uint8List byte array into a String.
  String uint8ListToString(Uint8List uint8list) {
    return utf8.decode(uint8list, allowMalformed: true);
  }

  /// Removes null characters (\0) from a String.
  String removeNullFromString(String str) {
    return str.replaceAll(RegExp(r'\x00'), '');
  }

  /// Encodes a String to a List of UTF-8 integers.
  List<int> stringToListInt(String str) {
    return utf8.encode(str);
  }

  /// Configured Logger instance.
  final logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      dateTimeFormat: DateTimeFormat.none,
      colors: false,
      printEmojis: true,
    ),
    level: kDebugMode ? Level.trace : Level.warning,
  );
}
