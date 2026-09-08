import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/my_utils.dart';
import '../../connection/providers/board_console_selector.dart';

/// Sends [command] fire-and-forget to the active board console (Serial first,
/// then PTY/SSH). Displays an error snackbar if no console is connected.
void sendBoardCommand(
  WidgetRef ref,
  BuildContext context,
  String command, {
  String terminator = '\r',
}) {
  final console = pickBoardConsole(ref);
  if (console == null) {
    m.showErrorSnackbar(context, 'No connected serial or PTY console');
    return;
  }
  console.send('${command.trimRight()}$terminator');
}
