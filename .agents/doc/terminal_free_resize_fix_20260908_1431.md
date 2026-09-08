# Terminal Free Resize & Overflow Prevention Fix

## Overview

The previous attempt to prevent `RenderFlex` overflow set `min: 150` and `min: 100` on `Area(flex: ...)` in `MultiSplitViewController`. In `multi_split_view`, setting `min` on a `flex` Area sets **minimum flex units**, not pixels. This clamped the flex ratio to 150:100, effectively locking the vertical divider in place and preventing vertical resizing.

This document details how free vertical and horizontal resizing was fully restored while resolving all `RenderFlex` pixel overflow errors across all window and pane sizes.

---

## Root Causes Identified

1. **Divider Locking via Area `min` (Flex vs Pixels)**:
   In `multi_split_view-3.6.2`, `Area.min` applies directly to the area's sizing unit (`flex` or `size`). When an Area uses `flex: 1` and `min: 100`, its flex factor is clamped to `math.max(1, 100) = 100`. This locked `_splitController` between `flex: 150` and `flex: 100`, making the divider appear frozen.
2. **True Cause of 0.75px / Sub-pixel RenderFlex Overflow**:
   When the user dragged the divider to make the terminal small (e.g. total height < 60px):
   - `LogPanel` height became ~`59.25px`.
   - `_Toolbar` took 32px.
   - The remaining height passed to `_TerminalPane` was `27.25px`.
   - `_TerminalPane`'s pane header was configured as `Container(height: 28)` containing a `Row`.
   - Inside `Row`, the child widgets (icon, text, action buttons) required 28px cross-axis height.
   - Constrained to `27.25px`, the `Row` overflowed vertically by `28.0 - 27.25 = 0.75px`.
3. **Horizontal Overflow During Pane Resizing**:
   When multiple terminal panes (e.g. SERIAL and PTY) were resized horizontally, shrinking any pane below ~`93px` caused the header `Row` (containing status dot, icon, label, clear button, and close button) to overflow horizontally on the right.

---

## Solutions Implemented

### 1. Restored Free MultiSplitView Resizing

Removed all `min` flex restrictions:

- In [`lib/features/home/home_screen.dart`](file:///D:/GIT/GitHub/term_template/lib/features/home/home_screen.dart#L30-L35):

  ```dart
  _splitController = MultiSplitViewController(
    areas: [
      Area(flex: 3, id: 'main'),
      Area(flex: 1, id: 'log'),
    ],
  );
  ```

- In [`lib/features/terminal/widgets/log_panel.dart`](file:///D:/GIT/GitHub/term_template/lib/features/terminal/widgets/log_panel.dart#L43-L73):

  ```dart
  _splitController = MultiSplitViewController(
    areas: [for (final t in tabs) Area(id: t.id, flex: 1)],
  );
  ```

The user can now drag the vertical and horizontal split view dividers freely across their full range.

### 2. Unconstrained Layout via `OverflowBox` and `ClipRect`

Instead of restricting user dragging, child rows and columns are isolated with `OverflowBox` and `ClipRect`:

- **Pane Header (`_TerminalPane`)**:
  - Wrapped header `Row` inside `OverflowBox(minWidth: effectiveW, maxWidth: effectiveW, minHeight: 28, maxHeight: 28)` inside a `ClipRect`.
  - The header `Row` is always guaranteed its full 28px height and at least 200px width.
  - `ClipRect` cleanly clips any excess during extreme drag positions.
  - Zero vertical or horizontal overflow regardless of how small the pane is dragged.
- **Terminal Pane Body (`_TerminalPane`)**:
  - If `maxHeight <= 28`: Renders only the header clipped with `ClipRect` without mounting `Column` or `Expanded(TerminalView)`.
  - If `maxHeight > 28`: Mounts `Column` with `header` and `Expanded(child: ClipRect(child: TerminalView(...)))`.
- **Toolbar (`_Toolbar`)**:
  - Wrapped toolbar `Row` inside `OverflowBox(minWidth: effectiveW, maxWidth: effectiveW, minHeight: 32, maxHeight: 32)` inside a `ClipRect`.
  - The toolbar `Row` is always guaranteed its full 32px height and at least 680px width.
  - If window width < 680px or height < 32px, `ClipRect` cleanly clips without throwing `RenderFlex` assertions.
- **Terminal Dock Body (`LogPanel`)**:
  - If `maxHeight <= 32`: Renders only `_Toolbar` clipped with `ClipRect`.
  - If `maxHeight > 32`: Mounts `ClipRect(child: Column(children: [_Toolbar, Expanded(MultiSplitView)]))`.

---

## Verification Results

### Automated Commands Executed

1. **Static Analysis**:
   - Command: `flutter analyze`
   - Result: Exit code 0 (`No issues found!`).
2. **Code Formatting**:
   - Command: `dart format lib test`
   - Result: Exit code 0, all files formatted cleanly.
3. **Automated Unit & Widget Tests**:
   - Command: `flutter test`
   - Result: Exit code 0, **12/12 tests passed**:
     - `Terminal bar vertical divider drags freely without overflow`
     - `Horizontal pane divider drags freely without overflow`
     - `LogPanel renders under small, boundary, and narrow constraints without overflow` (heights 15, 20, 27.25, 32, 45, 60, 100; widths 50, 100, 200, 400, 800)
     - `Folding and unfolding sidebar animates smoothly without overflow`
     - `TermTemplateApp loads and renders shell components`
     - All `MyUtils` and `SerialConfig` unit tests passed.
4. **Native Desktop Debug Compilation**:
   - Command: `flutter build windows --debug`
   - Result: Exit code 0 (`√ Built build\windows\x64\runner\Debug\term_template.exe` in 10.3s).
