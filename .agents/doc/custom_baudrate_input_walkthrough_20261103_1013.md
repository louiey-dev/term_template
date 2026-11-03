# Custom Baud Rate Input Support

## Overview

Added an interactive **Custom...** input item directly inside the baud rate dropdown listbox. Users can now select standard rates or specify any arbitrary custom baud rate (e.g. 74880, 250000, 2000000, 3000000). Custom baud rates are automatically validated, applied to the active serial connection, saved to the custom rates list in Hive, and restored on app launch.

## Changes Made

### 1. State Management & Persistence

In [`serial_pane_provider.dart`](file:///D:/GIT/GitHub/term_template/lib/features/connection/providers/serial_pane_provider.dart):

- Defined [`standardBaudRates`](file:///D:/GIT/GitHub/term_template/lib/features/connection/providers/serial_pane_provider.dart#L16-L28) containing standard preset speeds (`[9600, ..., 1500000]`).
- Added [`customBaudRatesProvider`](file:///D:/GIT/GitHub/term_template/lib/features/connection/providers/serial_pane_provider.dart#L30-L34) and [`CustomBaudRatesNotifier`](file:///D:/GIT/GitHub/term_template/lib/features/connection/providers/serial_pane_provider.dart#L36-L89):
  - Loads saved custom rates from the Hive `app_settings` box (`custom_baud_rates` key).
  - Automatically captures any previously restored custom baud rate on startup.
  - Supports adding (`add`) and removing (`remove`) custom baud rates with Hive persistence.

### 2. Connection Bar UI & Dialog

In [`connection_bar.dart`](file:///D:/GIT/GitHub/term_template/lib/features/connection/widgets/connection_bar.dart):

- Added `_customBaudRateValue = -1` sentinel.
- Combined `standardBaudRates`, user-saved `customBauds`, and current `config.baudRate` into `allBaudRates`.
- Appended a dedicated `Custom...` dropdown item styled with `Icons.add` and an ellipsis-safe text layout to prevent pixel overflow.
- Implemented `_showCustomBaudRateDialog` and [`_CustomBaudRateDialog`](file:///D:/GIT/GitHub/term_template/lib/features/connection/widgets/connection_bar.dart#L660-L930):
  - Number input field with numeric filtering, validation (`1` to `10,000,000` bps), and submit on Enter.
  - Quick-tap preset chips for common embedded rates (`74880`, `250000`, `500000`, `1000000`, `2000000`, `3000000`).
  - Interactive chips for previously saved custom baud rates with delete (`x`) buttons.

### 3. Testing and Verification

- Unit tests in [`serial_baud_rate_test.dart`](file:///D:/GIT/GitHub/term_template/test/unit/serial_baud_rate_test.dart#L76-L102):
  - Verified adding custom baud rate updates state and writes JSON to Hive.
  - Verified standard rates are not duplicated into the custom list.
  - Verified removing custom baud rates updates state and Hive storage.
- Widget test in [`widget_test.dart`](file:///D:/GIT/GitHub/term_template/test/widget_test.dart#L346-L385):
  - Opens baud rate dropdown.
  - Taps `Custom...`.
  - Enters `2000000` in the dialog and taps `Apply`.
  - Confirms the dropdown updates to `2000000` and values are persisted to Hive.

## Verification Results

- `flutter test`: All 22 unit and widget tests passed.
- `dart analyze`: Analyzed project — **No issues found**.
