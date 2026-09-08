# Terminal Vertical Fold and Overflow Prevention

## Overview

Added vertical fold and unfold functionality to the bottom TERMINAL panel while preserving free vertical and horizontal resizing without pixel overflow errors.

## Implemented Features

### 1. State Management

- Created `terminalFoldedProvider` (`StateProvider<bool>`) in [`terminal_instances.dart`](file:///D:/GIT/GitHub/term_template/lib/features/terminal/providers/terminal_instances.dart).
- Allows any component across the application to observe and trigger fold/unfold states.

### 2. Collapsible Split View Integration

- Integrated dynamic split view area sizing in [`home_screen.dart`](file:///D:/GIT/GitHub/term_template/lib/features/home/home_screen.dart):
  - When unfolded: Restores previous flex ratio `[Area(flex: _lastMainFlex), Area(flex: _lastLogFlex)]`.
  - When folded: Locks log panel to header height `[Area(flex: 1, id: 'main'), Area(size: 32, id: 'log')]`.
  - Auto-unfold: Dragging the splitter upward from the folded state automatically updates `terminalFoldedProvider` to `false`.
  - Shortcut: Added <kbd>Alt</kbd>+<kbd>T</kbd> key shortcut to toggle fold state.

### 3. Header & Toolbar Controls

- In [`log_panel.dart`](file:///D:/GIT/GitHub/term_template/lib/features/terminal/widgets/log_panel.dart):
  - Added fold/unfold toggle button with `Icons.keyboard_arrow_up` / `Icons.keyboard_arrow_down` and tooltip.
  - Added clickable "TERMINAL" header title that unfolds the panel when collapsed.
  - Isolated header layout inside `OverflowBox` and `ClipRect` with safe minimum bounds (`minToolbarW = 900.0`, `minHeaderW = 200.0`) to prevent any `RenderFlex` overflow during narrow horizontal or vertical resizing.

### 4. Global ConnectionBar Toggle

- In [`connection_bar.dart`](file:///D:/GIT/GitHub/term_template/lib/features/connection/widgets/connection_bar.dart):
  - Added a dedicated terminal fold/unfold button with `Icons.terminal` and tooltip `'Fold terminal panel (Alt+T)'` / `'Expand terminal panel (Alt+T)'`.

## Verification

### Automated Tests

- `flutter test test/widget_test.dart`:
  - `TermTemplateApp loads and renders shell components` - Passed
  - `Folding and unfolding sidebar animates smoothly without overflow` - Passed
  - `Terminal bar vertical divider drags freely without overflow` - Passed
  - `Horizontal pane divider drags freely without overflow` - Passed
  - `LogPanel renders under small, boundary, and narrow constraints without overflow` - Passed
  - `Terminal panel vertical fold and unfold toggle works correctly` - Passed
- Full suite `flutter test`: 13 of 13 tests passed.
- Static analysis: `flutter analyze` reported 0 issues.
