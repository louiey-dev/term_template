# DESIGN

Want template app based on sanc_term so same as sanc_term but simplified and optimized code base.
Will use as a reference for new project app.
Will copy code and paster so use relative path for easy copy.

## Purpose

Reusable custom APIs are now grouped under `lib/shared/`: `my_button.dart`, `my_panel.dart`, `my_widget.dart`, and `my_utils.dart`.

This repository is a compact copyable Flutter template for UART and terminal applications. It keeps the reusable transport, terminal, routing, logging, and widget foundation from `sanc_term` while excluding board-specific features.

## Architecture

- Refer sanc_term code based, this is reference code app
- Use same color theme and layout from sanc_term
- Remove all sub panels under PANELS from sanc_term and prepare one sample panel for reference
  - COMMON/General Settings
- Log panels should be same as sanc_term
  - ssh/ip/id/pass
  - log icons
  - panel split for serial/pty
- creates below for custom widgets under shared folder
  - my_button.dart
  - my_panel.dart
  - my_widget.dart

## State and lifecycle

UART configuration, terminal tabs, active pane, theme, and logs use keep-alive Riverpod providers. Panel navigation therefore does not reset UART/TERM configuration or active connections. Mutable native resources are owned by the connection and terminal providers and cleaned up through provider disposal.

## Log behavior

Transport data is appended to a bounded timestamped buffer. Pause stops terminal view updates while retaining captured data. Save opens a file dialog and exports the retained entries.

## Adding a project panel

## Platform behavior

The Flutter shell builds across targets. Serial and PTY functionality is enabled only where the native plugins support it; unsupported actions report a clear state instead of crashing the UI.

## Conventions

- Use relative imports for easy copying.
- Use `m.log/dbg/err` instead of direct `print` calls. (my_utils.dart)
- Add Dartdoc comments to public methods and reusable APIs.
- Keep custom widget styling in the `my_*` files so project panels stay small.
