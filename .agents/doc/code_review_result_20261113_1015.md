# `term_template` Code Review Result

**Date**: 2026-11-13
**Static Analysis**: `flutter analyze` passed with **0 issues found** (ran in 107.6s)
**Test Coverage**: `test/` currently contains **0 test files**

## 1. Executive Summary

`term_template` has a clean, modular feature-based structure (`core`, `features/connection`, `features/home`, `features/panels`, `features/terminal`, `services`, `shared`), uses Riverpod + `go_router` + `hive_ce` consistently, and includes a well-engineered direct Win32 serial backend (`_Win32SerialBackend`) that avoids `libserialport` multi-port USB CDC issues.

The main areas needing attention are:

1. **Resource & lifecycle leaks** when closing terminal/serial tabs.
2. **UI clipping and dropdown crash risks** in `LogPanel` and `ConnectionBar`.
3. **Cross-shell assumptions** in `ConsoleCommandSession` and shared logging in `FileLoggerNotifier`.
4. **Missing automated tests** (`test/` is empty) and missing serial port configuration options (port persistence, data/stop/parity/flow control).

---

## 2. Bugs & Resource Leaks

### 2.1 Serial & Terminal Tab Close Resource Leak (High)

- **Location**: [`lib/features/terminal/providers/terminal_instances.dart`](file:///D:/GIT/GitHub/term_template/lib/features/terminal/providers/terminal_instances.dart#L307-L322)
- **Issue**: `TerminalTabsNotifier.removeTab(String id)` removes the `TerminalTab` from state, but:
  1. It never calls `tab.controller.dispose()` or `tab.focusNode.dispose()`.
  2. `serialPaneNotifierProvider` in [`serial_pane_provider.dart`](file:///D:/GIT/GitHub/term_template/lib/features/connection/providers/serial_pane_provider.dart#L125-L128) is a `NotifierProvider.family` (not `autoDispose`). Closing a connected `SERIAL` tab removes its UI pane, but `SerialPaneNotifier._cleanup()` is never invoked—leaving the COM port open and `_readTimer` (`Timer.periodic` every 10 ms) running in the background.
- **Recommendation**:
  - Call `tab.controller.dispose()` and `tab.focusNode.dispose()` when removing a tab.
  - Explicitly disconnect/invalidate `serialPaneNotifierProvider(id)` (e.g., `ref.read(serialPaneNotifierProvider(id).notifier).disconnect()` and `ref.invalidate(serialPaneNotifierProvider(id))`) inside `removeTab`, or switch to `AutoDisposeFamilyNotifier`.

### 2.2 `DropdownButton` Assertion Crash When Selected Port Disappears (High)

- **Location**: [`lib/features/connection/widgets/connection_bar.dart`](file:///D:/GIT/GitHub/term_template/lib/features/connection/widgets/connection_bar.dart#L147-L173)
- **Issue**: `buildDropdown<String>` receives `value: config.port.isEmpty ? null : config.port` and `items: ports.map(...)`. If a user selects `COM19`, disconnects/unplugs the USB adapter, and clicks **Scan**, `ports` no longer contains `COM19`. Flutter's `DropdownButton` asserts that `value` must match either `null` or exactly one item in `items`, throwing a widget build exception.
- **Recommendation**: Guard the value before passing it to `buildDropdown`:

  ```dart
  final selectedPort =
      config.port.isNotEmpty && ports.contains(config.port) ? config.port : null;
  ```

### 2.3 `LogPanel` Toolbar Clipped on Narrow Windows (Medium)

- **Location**: [`lib/features/terminal/widgets/log_panel.dart`](file:///D:/GIT/GitHub/term_template/lib/features/terminal/widgets/log_panel.dart#L488-L505)
- **Issue**: `_Toolbar` wraps its `Row` in `ClipRect` + `OverflowBox` with `const minToolbarW = 900.0`. Whenever the pane or window width is under `900 px` (note `HomeScreen` allows `minWidth = 700.0`), right-aligned controls (**Pause**, **Save to file**, **Timestamp**, **Paste Delay**) are silently clipped off-screen and unreachable.
- **Recommendation**: Replace the `OverflowBox(minWidth: 900.0)` with a horizontal `SingleChildScrollView(scrollDirection: Axis.horizontal)` (matching `ConnectionBar` and `_BarSlot`).

### 2.4 `ConsoleCommandSession` Assumes a POSIX Shell (Medium)

- **Location**: [`lib/features/connection/providers/board_console.dart`](file:///D:/GIT/GitHub/term_template/lib/features/connection/providers/board_console.dart#L53-L66)
- **Issue**: `ConsoleCommandSession.run()` appends `; echo SANC"END"$nonce` to every command.
  - On Windows `cmd.exe` PTY (`_shell` in `log_panel.dart`), `;` is not a command separator and `"` is printed literally, so `SANC"END"<nonce>` never matches `_marker = 'SANCEND$nonce'` and always times out.
  - On embedded RTOS/bootloader CLIs (Zephyr shell, U-Boot, AT modems, FreeRTOS+CLI), `; echo ...` is invalid syntax.
- **Recommendation**: Support shell-aware command framing (e.g., `& echo SANCEND%nonce%` or no marker for `cmd.exe`, or prompt/idle-based completion for non-POSIX serial targets).

### 2.5 Silent Partial-Write Drop in `_Win32SerialBackend.write` (Medium)

- **Location**: [`lib/features/connection/providers/serial_pane_provider.dart`](file:///D:/GIT/GitHub/term_template/lib/features/connection/providers/serial_pane_provider.dart#L976-L999)
- **Issue**: If `WaitForSingleObject(_writeEvent, 250)` times out, `write()` cancels the overlapped I/O and `break`s out of the chunk loop without throwing an error or returning the number of bytes written. Large pastes or firmware transfers can silently truncate mid-stream.
- **Recommendation**: Throw a `TimeoutException` or `StateError` when a write chunk times out so callers and `_handleFatalError` can surface the failure.

### 2.6 Shared `FileLoggerNotifier` Interleaves Output Across All Panes (Low/Medium)

- **Location**: [`lib/services/file_logger_service.dart`](file:///D:/GIT/GitHub/term_template/lib/services/file_logger_service.dart#L113-L140), [`serial_pane_provider.dart`](file:///D:/GIT/GitHub/term_template/lib/features/connection/providers/serial_pane_provider.dart#L372), [`log_panel.dart`](file:///D:/GIT/GitHub/term_template/lib/features/terminal/widgets/log_panel.dart#L148)
- **Issue**:
  - Every active serial pane and PTY pane writes into the single global `fileLoggerNotifierProvider` sink without a pane prefix or per-pane file option, interleaving concurrent outputs.
  - Line 145 of `file_logger_service.dart` has `.replaceAll('', '')` (a no-op, likely intended to strip `\uFFFD` replacement characters).
  - `_sink!.write(...)` is not guarded against disk-full or I/O errors.

### 2.7 Hidden Panel Route Not Enforced in `app_router.dart` (Low)

- **Location**: [`lib/core/router/app_router.dart`](file:///D:/GIT/GitHub/term_template/lib/core/router/app_router.dart#L39-L44), [`lib/features/panels/panel_registry.dart`](file:///D:/GIT/GitHub/term_template/lib/features/panels/panel_registry.dart#L44-L56)
- **Issue**: `isPanelHidden(id)` is defined in `panel_registry.dart` and `MenuSidebar` filters `isHidden` items, but `app_router.dart` never checks `isPanelHidden(id)`—so navigating directly to `/home/panel/<hiddenId>` or restoring a previously persisted `last_route` still renders hidden panels.

---

## 3. Recommended Improvements & Features to Add

### 3.1 Serial Port UX & Configuration

- **Auto-scan COM ports on startup**: `AvailablePortsNotifier.build()` returns `[]`, forcing users to click **Scan** every launch. Triggering an initial `scan()` on startup (or in `HomeScreen.initState`) improves out-of-the-box UX.
- **Persist selected COM port per pane**: `SerialPaneNotifier._savePaneConfig` saves `baudRate`, `encoding`, and `newLine`, but `setPort()` does not persist `port`. Persisting `port` per tab (and validating against scanned ports) avoids re-selecting the COM port every session.
- **Expose full serial framing & flow control**: `_Win32SerialBackend.open()` hardcodes `8N1` and disables RTS/CTS and XON/XOFF flow control. Adding `dataBits`, `parity`, `stopBits`, and `flowControl` to `SerialConfig` and `_ComSettingsDialog` makes the template viable for industrial/legacy UART devices.
- **Async/isolate serial writes**: `_Win32SerialBackend.write()` blocks the UI thread inside `WaitForSingleObject(_writeEvent, 250)` per 16 KB chunk. Moving large writes or paste streaming off the main thread prevents UI stutter on slow baud rates.

### 3.2 Terminal & Shell Enhancements

- **Configurable PTY shell on Windows**: `_shell` in `log_panel.dart` hardcodes `cmd.exe /k chcp 65001`. Allowing PowerShell (`pwsh.exe` / `powershell.exe`) or user-configured shell profiles in settings is a common developer expectation.
- **Terminal search & scrollback export**: `xterm` supports search highlighting (`searchHitBackground` is already configured in `buildTerminalTheme` in `app_theme.dart`), but there is currently no search bar UI (`Ctrl+F`) wired up in `_TerminalPane`.

### 3.3 Code Quality & Testing

- **Add unit and widget tests**: `test/` is currently empty. High-value targets:
  - `SerialConfig` JSON serialization (`toJson` / `fromJson`).
  - `ConsoleCommandSession` marker extraction and timeout handling.
  - `FileLoggerNotifier` ANSI stripping and timestamp formatting.
  - `CmdHistoryNotifier` pin/unpin/recents cap and corrupt-JSON fallback.
  - `ConnectionBar` and `LogPanel` narrow-width layout tests (overflow regression checks).
- **Consolidate logging utilities**: [`lib/shared/my_utils.dart`](file:///D:/GIT/GitHub/term_template/lib/shared/my_utils.dart#L51-L112) defines `m.log`, `m.dbg`, `m.err` using `debugPrint` alongside an unused `Logger` instance (`m.logger`). Standardizing on one approach reduces boilerplate.
- **Log Hive recovery fallback**: [`lib/main.dart`](file:///D:/GIT/GitHub/term_template/lib/main.dart#L43-L51) silently falls back to an in-memory box (`bytes: Uint8List(0)`) if `app_settings` fails to open, without surfacing or logging the error.

---

## 4. Summary Priority Matrix

| Priority | Item | Location |
| :--- | :--- | :--- |
| **High** | Dispose `TerminalController`/`FocusNode` and close serial port on tab remove | [`terminal_instances.dart`](file:///D:/GIT/GitHub/term_template/lib/features/terminal/providers/terminal_instances.dart#L307-L322) |
| **High** | Guard `ConnectionBar` port dropdown `value` against missing scanned ports | [`connection_bar.dart`](file:///D:/GIT/GitHub/term_template/lib/features/connection/widgets/connection_bar.dart#L147-L173) |
| **Medium** | Make `LogPanel` `_Toolbar` horizontally scrollable instead of clipping at 900 px | [`log_panel.dart`](file:///D:/GIT/GitHub/term_template/lib/features/terminal/widgets/log_panel.dart#L488-L505) |
| **Medium** | Handle non-POSIX / `cmd.exe` shells in `ConsoleCommandSession` | [`board_console.dart`](file:///D:/GIT/GitHub/term_template/lib/features/connection/providers/board_console.dart#L53-L66) |
| **Medium** | Throw on Win32 `WriteFile` timeout instead of silent partial-write break | [`serial_pane_provider.dart`](file:///D:/GIT/GitHub/term_template/lib/features/connection/providers/serial_pane_provider.dart#L976-L999) |
| **Low** | Enforce `isPanelHidden`, fix `.replaceAll('', '')`, add unit/widget tests | [`app_router.dart`](file:///D:/GIT/GitHub/term_template/lib/core/router/app_router.dart#L39-L44), [`file_logger_service.dart`](file:///D:/GIT/GitHub/term_template/lib/services/file_logger_service.dart#L142-L145) |
