# Tasks

## Completed

- [x] Streamline `pubspec.yaml` with essential UART/terminal dependencies and remove heavy board modules (WebRTC, MQTT, BLE, TTS, Archive, Crypto).
- [x] Implement standard Riverpod state management and pure Dart models without `build_runner` or code-gen overhead.
- [x] Establish unified theme and ANSI 16-color xterm palette in `lib/core/theme/` identical to `sanc_term`.
- [x] Build reusable shared UI modules in `lib/shared/`: `my_button.dart`, `my_panel.dart`, `my_widget.dart`, and `my_utils.dart`.
- [x] Build fast Windows registry serial scanner and per-tab serial connection manager with encoding and line-ending controls.
- [x] Implement multi-split terminal dock (`LogPanel`) with PTY shell execution, SSH credentials, pause/resume, timestamping, paste delay, and file logging.
- [x] Build responsive `HomeScreen` with `ConnectionBar`, collapsible `MenuSidebar`, and keyboard shortcuts (`Alt+1..9`).
- [x] Implement reference panel `COMMON / General Settings` demonstrating board command transmission.
- [x] Verify static analysis (`flutter analyze` - 0 issues), code formatting (`dart format`), and automated tests (`flutter test` - all passed).
- [x] Verify native Windows desktop build (`flutter build windows --debug`).
