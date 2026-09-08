# UART/TERM Template Walkthrough

The UART/terminal Flutter project template has been completed. It provides a lightweight, highly optimized foundation based on `sanc_term`, retaining the same layout, color theme, and terminal capabilities while eliminating code generation overhead and board-specific bloat.

## Summary of Accomplishments

### 1. Architecture & Dependency Optimization

- **Pure Dart & Standard Riverpod**: Eliminated `freezed`, `riverpod_generator`, and `build_runner`. Models (`SerialConfig`, `TerminalTab`, `PasteSettings`, `TerminalCredentials`) and notifiers use pure Dart and standard Riverpod (`NotifierProvider`, `Provider`, `StateProvider`).
- **Clean Dependency Tree**: Removed 10+ heavy, board-specific packages (WebRTC, MQTT, BLE, TTS, Archive, Crypto) while keeping essential native transport and terminal packages (`flutter_libserialport`, `flutter_pty`, `xterm: path: ../xterm.dart`, `multi_split_view`, `hive_ce`).
- **100% Relative Imports**: All imports within `lib/` use relative paths, making files and folders directly copy-pasteable into new projects without package rename friction.

### 2. Core Themes & Custom Shared API

- **App Theme (`lib/core/theme/app_theme.dart`)**: Dark (`0xFF1A1A2E`) and light (`0xFFF0F0F8`) palettes matching `sanc_term`, plus an xterm ANSI 16-color theme tuned for high contrast.
- **Persistent Theme Mode (`lib/core/theme/theme_provider.dart`)**: Saved in Hive `app_settings`.
- **Reusable Shared APIs (`lib/shared/`)**:
  - `my_utils.dart`: Global `m` instance with `log()`, `dbg()`, `err()`, snackbars, and byte conversion helpers.
  - `my_button.dart`: `PanelActionButton` and `PanelToggleButton`.
  - `my_panel.dart`: `MyPanel`, `MyPanelBody`, `PanelHeader`, `PanelBody`.
  - `my_widget.dart`: `buildDropdown`, `ToolbarDivider`, `StatusBadge`, `InfoTile`, `ProgressBar`, and `verticalDivider`.

### 3. Transport, Terminal & Connection Features

- **Port Scanner (`serial_config_notifier.dart`)**: Direct Windows registry lookup (`HKLM\HARDWARE\DEVICEMAP\SERIALCOMM`) for instant COM port enumeration without driver stall.
- **Independent Serial Panes (`serial_pane_provider.dart`)**: Family notifier managing separate COM port connections per terminal pane with keep-alive state across panel navigation.
- **Top Connection Bar (`connection_bar.dart`)**: COM port dropdown, baud rate selector (9600 to 1,500,000), scan button, connect/disconnect button, COM settings dialog (encoding/newline), About dialog, theme switcher, and live connection status pill.
- **Multi-Split Terminal Dock (`log_panel.dart`)**:
  - Horizontal resizable split panes supporting Serial and PTY shells (`cmd.exe` on Windows / `$SHELL` on macOS/Linux).
  - Add tab dropdown (+ New Serial, + New PTY).
  - SSH quick-connect fields: `[SSH]` trigger button, IP, username, password.
  - Pause/resume toggle (gates terminal view & logger while maintaining live I/O stream).
  - Timestamp prefix toggle.
  - File logger start/stop with directory picker (`FilePicker.getDirectoryPath`).
  - Paste delay settings (off, fast, medium, slow, custom) to prevent hardware buffer overruns.
  - Clear pane buffer and per-pane close buttons.
  - Right-click copy selection or paste text.

### 4. Layout & Reference Panel

- **Home Screen (`home_screen.dart`)**: Vertical split view separating top content and bottom log dock, responsive with minimum constraints, and keyboard shortcut handler (`Alt+1..9` to switch terminal focus).
- **Sidebar (`menu_sidebar.dart`)**: Collapsible animated sidebar (52px collapsed with tooltips, 220px expanded with groups). Uses `OverflowBox` and `ClipRect` to ensure zero `RenderFlex` overflow during fold/unfold transitions.
- **Router (`app_router.dart`)**: Declarative `GoRouter` mapping `/home` and `/home/panel/:panelId` with route persistence in Hive.
- **Reference Panel (`cm_general_settings.dart`)**: Reference panel under `COMMON / General Settings` demonstrating command transmission to active consoles via `sendBoardCommand`.

## Verification Results

### Commands Executed

1. **Dependency Resolution**:
   - Command: `flutter pub get`
   - Result: Exit code 0, all dependencies resolved successfully.
2. **Static Analysis**:
   - Command: `flutter analyze`
   - Result: Exit code 0 (`No issues found!`).
3. **Code Formatting**:
   - Command: `dart format lib test`
   - Result: Exit code 0, 31 files formatted.
4. **Automated Unit & Widget Tests**:
   - Command: `flutter test`
   - Result: Exit code 0, 8/8 tests passed:
     - `MyUtils Tests stringToUint8List and uint8ListToString`
     - `MyUtils Tests removeNullFromString`
     - `MyUtils Tests listIntToString`
     - `SerialConfig Model Tests default values`
     - `SerialConfig Model Tests copyWith updates fields correctly`
     - `SerialConfig Model Tests toJson and fromJson round-trip`
     - `SerialConfig Model Tests NewLine suffix mapping`
     - `TermTemplateApp loads and renders shell components`
5. **Native Desktop Compilation**:
   - Command: `flutter build windows --debug`
   - Result: Exit code 0 (`√ Built build\windows\x64\runner\Debug\term_template.exe`).
6. **Markdown Lint Compliance**:
   - Command: `cmd.exe /c npx --yes markdownlint-cli -c .markdownlint.json <files>`
   - Result: Exit code 0 across all `.agents/` documentation files.

## How to Copy & Extend This Template for a New Project

1. **Copy the Template**:
   - Copy the `term_template` directory to your new project location.
   - Rename `term_template` in `pubspec.yaml` and `term_template.iml` if desired.
2. **Add a New Panel**:
   - Create your panel widget under `lib/features/panels/<your_feature>/<your_panel>.dart` using `MyPanel` and `MyPanelBody` from `../../shared/my_panel.dart`.
   - Register the panel in `lib/features/panels/panel_registry.dart`:

     ```dart
     panelRegistry['my_custom_panel'] = () => const MyCustomPanel();
     panelGroups.add(
       const PanelGroup(
         title: 'MY FEATURE',
         icon: Icons.developer_board,
         items: [
           PanelEntry(
             id: 'my_custom_panel',
             label: 'Custom Controls',
             description: 'Controls for target board',
             icon: Icons.tune,
           ),
         ],
       ),
     );
     ```

3. **Send Board Commands**:
   - Use `sendBoardCommand(ref, context, 'my_cmd\r')` to send commands over the active serial or PTY connection without managing low-level streams.
