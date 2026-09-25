import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/settings.dart';
import 'package:mobile/core/persistence/settings_storage.dart';
import 'package:mobile/features/settings/presentation/settings_page.dart';

void main() {
  testWidgets('SettingsPage renders all controls and toggles', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final storage = SettingsStorage();
    const initial = HanglySettings.defaults;

    await tester.pumpWidget(MaterialApp(
      home: SettingsPage(
        initialSettings: initial,
        storage: storage,
      ),
    ));
    await tester.pumpAndSettle();

    // Verify section headers
    expect(find.text('APPEARANCE & ROPE'), findsOneWidget);
    expect(find.text('PHYSICS & INTERACTION'), findsOneWidget);
    expect(find.text('ANDROID BACKGROUND & OVERLAY'), findsOneWidget);

    // Verify sliders
    expect(find.text('Charm Size'), findsOneWidget);
    expect(find.text('Rope Length'), findsOneWidget);
    expect(find.text('Motion Intensity'), findsOneWidget);

    // Verify switches
    expect(find.text('Haptic Feedback'), findsOneWidget);
    expect(find.text('Device Motion (Sensors)'), findsOneWidget);
    expect(find.text('Always-On Overlay Mode'), findsOneWidget);

    // Verify Reset button
    expect(find.text('Reset to Defaults'), findsOneWidget);
  });
}
