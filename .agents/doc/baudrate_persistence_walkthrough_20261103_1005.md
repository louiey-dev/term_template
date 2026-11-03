# Baud Rate Persistence and Restoration

## Overview

Previously, the baud rate defaulted to 115200 on application launch, requiring users who frequently work with other baud rates (such as 1500000 for high-speed microcontrollers) to re-select their preferred rate every time the app opened.

This update introduces automatic persistence and restoration of the selected baud rate using the existing Hive `app_settings` storage box.

## Changes Made

### 1. Serial Pane Provider Persistence Logic

In [`serial_pane_provider.dart`](file:///D:/GIT/GitHub/term_template/lib/features/connection/providers/serial_pane_provider.dart):

- Added `static const _baudRateKey = 'serial_baud_rate'` and `static const int defaultBaudRate = 115200`.
- Added [`SerialPaneNotifier.getPersistedBaudRate()`](file:///D:/GIT/GitHub/term_template/lib/features/connection/providers/serial_pane_provider.dart#L86-L98) to load the last stored baud rate from the Hive `app_settings` box on startup.
- Updated [`SerialPaneNotifier.build`](file:///D:/GIT/GitHub/term_template/lib/features/connection/providers/serial_pane_provider.dart#L100-L107) so newly initialized serial panes default to the persisted baud rate rather than hardcoding 115200.
- Updated [`SerialPaneNotifier.setBaudRate`](file:///D:/GIT/GitHub/term_template/lib/features/connection/providers/serial_pane_provider.dart#L137-L147) to immediately persist the chosen baud rate to Hive whenever the user updates the selection.

### 2. Connection Bar UI Updates

In [`connection_bar.dart`](file:///D:/GIT/GitHub/term_template/lib/features/connection/widgets/connection_bar.dart):

- Ensured that when no serial pane is explicitly focused, [`ConnectionBar`](file:///D:/GIT/GitHub/term_template/lib/features/connection/widgets/connection_bar.dart#L28-L54) falls back to `SerialConfig(baudRate: SerialPaneNotifier.getPersistedBaudRate())` so the persisted baud rate remains visible and selected.
- Handled dynamic baud rate inclusion in `availableBaudRates` so any custom or non-standard restored baud rate is safely selectable without dropdown assertions.
- Fixed theme switcher tooltip text ordering to correctly reflect cycle targets.

### 3. Testing and Verification

- Created [`serial_baud_rate_test.dart`](file:///D:/GIT/GitHub/term_template/test/unit/serial_baud_rate_test.dart) covering:
  - Defaulting to 115200 when no stored value exists.
  - Correct restoration of saved baud rates (e.g. 1500000) from Hive.
  - State update and Hive write verification when calling `setBaudRate`.
- Added end-to-end widget test in [`widget_test.dart`](file:///D:/GIT/GitHub/term_template/test/widget_test.dart#L318-L344) verifying that launching the app with a stored baud rate of 1500000 initializes the dropdown to 1500000, and switching it to 115200 updates both UI and Hive storage.

## Verification Results

- `flutter test`: Ran all 20 unit and widget tests — **20 passed**.
- `dart analyze`: Analyzed project — **No issues found**.
