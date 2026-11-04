import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:term_template/shared/my_button.dart';
import 'package:term_template/shared/my_panel.dart';
import 'package:term_template/shared/my_widget.dart';

void main() {
  testWidgets('panel headers fit narrow widths with long text and actions', (
    tester,
  ) async {
    for (final width in [40.0, 60.0, 100.0, 200.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PanelHeader(
                      icon: Icons.settings,
                      iconColor: Colors.blue,
                      title: 'A very long panel title',
                      subtitle: 'A very long panel subtitle',
                      actions: const [
                        PanelActionButton(
                          icon: Icons.refresh,
                          label: 'A very long action label',
                        ),
                      ],
                    ),
                    const MyPanelBody(
                      icon: Icons.info,
                      title: 'A very long section title',
                      subtitle: 'A very long section subtitle',
                      trailing: StatusBadge(
                        label: 'A very long status label',
                        color: Colors.green,
                      ),
                      child: SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'width: $width');
    }
  });

  testWidgets('long metrics and badges fit in a narrow Wrap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 80,
            child: Wrap(
              children: [
                InfoTile(
                  label: 'A very long telemetry label',
                  value: '123456789012345678901234567890',
                  unit: 'units',
                ),
                StatusBadge(
                  label: 'A very long status label',
                  color: Colors.green,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(InfoTile)).width, lessThanOrEqualTo(80));
    expect(
      tester.getSize(find.byType(StatusBadge)).width,
      lessThanOrEqualTo(80),
    );
  });

  testWidgets('buttons grow vertically for enlarged text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3)),
            child: const Wrap(
              children: [
                PanelActionButton(icon: Icons.play_arrow, label: 'Run'),
                PanelToggleButton(icon: Icons.power, label: 'Enable'),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(PanelActionButton)).height,
      greaterThan(30),
    );
    expect(
      tester.getSize(find.byType(PanelToggleButton)).height,
      greaterThan(30),
    );
  });

  testWidgets('dropdown respects a narrower parent width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 60,
            child: Builder(
              builder: (context) => buildDropdown<String>(
                context,
                hint: 'A very long hint',
                items: const [
                  DropdownMenuItem(value: 'one', child: Text('One')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(DropdownButton<String>)).width,
      lessThan(60),
    );
  });
}
