# Pink Theme Implementation

## Overview

Added a dark plum/pink theme variant (`AppColors.pink` and `AppTheme.pinkTheme`) with vibrant rose accents, high-contrast text, and xterm terminal palette integration.

## Changes Made

### 1. Color Palette & Theme Definition

In [`app_theme.dart`](file:///D:/GIT/GitHub/term_template/lib/core/theme/app_theme.dart):

- Added [`AppColors.pink`](file:///D:/GIT/GitHub/term_template/lib/core/theme/app_theme.dart#L100-L115):
  - `background`: `0xFF20121D` (deep plum dark background)
  - `card`: `0xFF281724` (elevated card container)
  - `sidebar`: `0xFF1A0C17` (dark rose panel background)
  - `surface`: `0xFF351F30` (interactive controls & inputs)
  - `border`: `0xFF4D2C45` (subtle plum border)
  - `primary`: `0xFFF472B6` (vibrant rose pink accent)
  - `primaryForeground`: `0xFF20121D` (dark high-contrast text on primary buttons)
  - `foreground`: `0xFFFCE7F3` (legible light rose-white text)
  - `muted`: `0xFFA87D98` (soft rose-grey secondary text)
  - `warning`: `0xFFFBBF24`, `destructive`: `0xFFF43F5E`, `success`: `0xFF34D399`, `chartBlue`: `0xFFC084FC`
- Added `AppTheme.pinkTheme` in [`AppTheme`](file:///D:/GIT/GitHub/term_template/lib/core/theme/app_theme.dart#L210-L215) using `_build(AppColors.pink, Brightness.dark)`.

### 2. Theme Provider & State Management

In [`theme_provider.dart`](file:///D:/GIT/GitHub/term_template/lib/core/theme/theme_provider.dart):

- Added `AppThemeMode.pink('Pink', Icons.favorite_outline)`.
- Updated `themeData` switch to map `AppThemeMode.pink` to `AppTheme.pinkTheme`.
- Updated `_parse` to deserialize `'pink'` from Hive.
- Updated cycle: `light -> dark -> darkBlue -> medium -> green -> pink -> light`.

### 3. Toolbar Integration

In [`connection_bar.dart`](file:///D:/GIT/GitHub/term_template/lib/features/connection/widgets/connection_bar.dart#L245-L260):

- Updated theme toggle button tooltip to cycle through the Pink theme.
- Utilized `themeMode.icon` dynamically (`Icons.favorite_outline` for Pink).

### 4. Testing and Verification

- Updated [`widget_test.dart`](file:///D:/GIT/GitHub/term_template/test/widget_test.dart#L272-L318) to verify cycling through all 6 theme modes (Dark Blue -> Medium -> Green -> Pink -> Light -> Dark -> Dark Blue).
- Verified `xterm` terminal styling with `buildTerminalTheme`.

## Verification Results

- `flutter test`: All 22 tests passed.
- `dart analyze`: Analyzed project — **No issues found**.
