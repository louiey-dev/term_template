# UART/TERM Template Implementation Plan

## Goal

Provide a small, copyable Flutter foundation for UART and terminal projects based on the reusable parts of `sanc_term`.

## Implemented scope

- Riverpod and go_router application shell.
- Keep-alive UART configuration and terminal state.
- Serial scanning and per-pane serial connections.
- Optional PTY panes with lifecycle cleanup.
- xterm rendering with a local `../xterm.dart` dependency.
- Timestamped bounded logs.
- Pause, timestamp toggle, clear, and Save As(default to desktop) controls.
- Reusable `my_button.dart`, `my_panel.dart`, `my_widget.dart`, and `my_utils.dart` APIs.
- Generic routed sample panel for project-specific board commands.

## Extension guide

Add new board features under `lib/features/`, register a route in `lib/core/router/app_router.dart`, and add a sidebar entry in `lib/features/home/menu_sidebar.dart`. Read UART/TERM state from the keep-alive providers so changing panels does not reset the connection or configuration.

Use `m.log/dbg/err` instead of direct `print` calls. (my_utils.dart)
Add Dartdoc comments to public methods. Keep transport cleanup in the provider that owns the native resource.

## Validation

Run `dart format lib test`, `flutter analyze`, and `flutter test`. Verify serial and PTY behavior manually on the target desktop platform because those paths require native hardware/plugin support.
