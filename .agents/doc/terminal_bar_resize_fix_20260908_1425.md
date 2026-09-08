# Terminal Bar Resize RenderFlex Overflow Fix

## Overview

When resizing the terminal bar divider vertically in `HomeScreen`, a `RenderFlex overflowed by 0.750 pixels on the bottom` exception occurred:

- `Column` in `lib/features/terminal/widgets/log_panel.dart:267:14` (`_TerminalPane`)
- `Column` in `lib/features/terminal/widgets/log_panel.dart:181:14` (`LogPanel`)

This document outlines the root cause analysis, multi-layered defensive solution applied, and verification test results.

---

## Root Cause Analysis

1. **Unbounded Split Area Reduction**:
   In `lib/features/home/home_screen.dart`, `MultiSplitViewController` initialized `Area(flex: 3, id: 'main')` and `Area(flex: 1, id: 'log')` without a `min` parameter. When the user dragged the horizontal divider downward toward the bottom edge, the allocated height for `log` was permitted to shrink below the minimum height required by its children.
2. **Fixed Height Sub-Pixel Collision**:
   `LogPanel` requires a 32px `_Toolbar`. Inside the `MultiSplitView`, `_TerminalPane` requires a 28px pane header.
   When the total height allocated to `LogPanel` shrunk to ~59.25px:
   - `_Toolbar` took 32.0px.
   - `Expanded` took the remaining `59.25 - 32.0 = 27.25px`.
   - `_TerminalPane` received `maxHeight: 27.25px`.
   - Inside `_TerminalPane`, the header alone requested `28.0px`.
   - `28.0 - 27.25 = 0.75px`, triggering Flutter's `RenderFlex overflowed by 0.750 pixels on the bottom` assertion failure.
3. **Missing Horizontal Pane Constraints**:
   Similarly, horizontal tab areas in `_LogPanelState` (`Area(id: t.id, flex: 1)`) lacked `min` constraints, allowing panes to be dragged to 0 width.
4. **Toolbar Horizontal Responsiveness**:
   The toolbar contained IP, ID, Password, SSH button, and action controls that could overflow if the window or container became narrow.

---

## Solutions Implemented

### 1. Enforced Minimum Split Area Constraints

- In `lib/features/home/home_screen.dart`:
  - Configured `Area(flex: 3, id: 'main', min: 150)`.
  - Configured `Area(flex: 1, id: 'log', min: 100)`.
  - Guarantees the divider cannot be dragged lower than 100px of terminal height (`32px toolbar + 28px header + 40px terminal view`).
- In `lib/features/terminal/widgets/log_panel.dart`:
  - Added `min: 120` to each tab `Area` in `initState` and `_syncAreas`, preventing horizontal tabs from collapsing below 120px.

### 2. Defensive Layout in `LogPanel`

Wrapped `LogPanel.build` with `LayoutBuilder`:

- If `constraints.maxHeight <= 32`: Renders the toolbar clipped inside `ClipRect(child: SizedBox(height: maxHeight))` without mounting the vertical `Column` or `Expanded(MultiSplitView)`.
- If `constraints.maxHeight > 32`: Renders the full `Column` with toolbar and multi-split terminal panes.

### 3. Defensive Layout in `_TerminalPane`

Wrapped `_TerminalPane.build` with `LayoutBuilder`:

- If `constraints.maxHeight <= 28`: Renders only the header clipped inside `ClipRect(child: SizedBox(height: maxHeight))` without mounting `Column` with `Expanded(TerminalView)`.
- If `constraints.maxHeight > 28`: Renders the full `Column` with header and expanded terminal view.

### 4. Responsive Toolbar Layout

Refactored `_Toolbar.build` with `LayoutBuilder`:

- If `constraints.maxWidth >= 680`: Uses `Spacer()` to neatly push credentials and action icons to the far right.
- If `constraints.maxWidth < 680`: Automatically wraps children into a horizontal `SingleChildScrollView` with fixed spacing, preventing horizontal `RenderFlex` overflows.

---

## Verification Results

### Commands Executed

1. **Static Analysis**:
   - Command: `flutter analyze`
   - Result: Exit code 0 (`No issues found!`).
2. **Automated Unit & Widget Tests**:
   - Command: `flutter test`
   - Result: Exit code 0, 11/11 tests passed:
     - `MyUtils Tests stringToUint8List and uint8ListToString`
     - `MyUtils Tests removeNullFromString`
     - `MyUtils Tests listIntToString`
     - `SerialConfig Model Tests default values`
     - `SerialConfig Model Tests copyWith updates fields correctly`
     - `SerialConfig Model Tests toJson and fromJson round-trip`
     - `SerialConfig Model Tests NewLine suffix mapping`
     - `TermTemplateApp loads and renders shell components`
     - `Folding and unfolding sidebar animates smoothly without overflow`
     - `Terminal bar divider drag and window resize do not overflow`
     - `LogPanel renders under small and boundary heights without overflow` (tested heights 20, 27.25, 32, 50, and 100).
3. **Native Desktop Debug Build**:
   - Command: `flutter build windows --debug`
   - Result: Exit code 0 (`√ Built build\windows\x64\runner\Debug\term_template.exe`).
