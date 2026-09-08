# Sample Widgets in CmGeneralSettingsPanel

## Overview

Added reference sample implementations for [`StatusBadge`](file:///D:/GIT/GitHub/term_template/lib/shared/my_widget.dart#L59), [`InfoTile`](file:///D:/GIT/GitHub/term_template/lib/shared/my_widget.dart#L87), and [`ProgressBar`](file:///D:/GIT/GitHub/term_template/lib/shared/my_widget.dart#L146) within [`CmGeneralSettingsPanel`](file:///D:/GIT/GitHub/term_template/lib/features/panels/common/cm_general_settings.dart) under the "Statistics & Diagnostics" section.

## Implemented Samples

### 1. StatusBadge Showcase

Demonstrates using badges for both card headers (trailing) and inline system status indicators:

- **Section Trailing Badge**: `StatusBadge(label: 'MONITORING', color: c.success)`
- **Inline Status States**:
  - `StatusBadge(label: 'ONLINE', color: c.success)`
  - `StatusBadge(label: 'STANDBY', color: c.warning)`
  - `StatusBadge(label: 'OFFLINE', color: c.destructive)`
  - `StatusBadge(label: 'IDLE', color: c.muted)`

### 2. InfoTile Metric Grid

Demonstrates telemetry metrics organized in a responsive `Wrap` layout:

- **CPU Usage**: `24 %` with `Icons.memory` and `c.primary` highlight
- **Memory Used**: `3.2 GB` with `Icons.storage` and `c.foreground`
- **Board Temp**: `42.5 °C` with `Icons.thermostat` and `c.warning` highlight
- **Fan Speed**: `2400 RPM` with `Icons.speed` and `c.foreground`

### 3. ProgressBar Resource Utilization

Demonstrates proportional horizontal progress bars with label and text percentage readouts:

- **CPU Core Load**: `35%` (`c.primary`)
- **Memory Allocation**: `4.9 / 8.0 GB (62%)` (`c.warning`)
- **Storage (/dev/root)**: `26.8 / 32.0 GB (84%)` (`c.destructive`)

## Verification

### Automated Tests

- `flutter test`: 14 of 14 tests passed (including new widget test `CmGeneralSettingsPanel renders StatusBadge, InfoTile, and ProgressBar samples`).
- `flutter analyze`: Passed with 0 issues.
- `flutter build windows --debug`: Succeeded with exit code 0.
