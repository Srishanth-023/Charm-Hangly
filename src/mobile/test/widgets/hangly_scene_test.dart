import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/core/persistence/settings_storage.dart';
import 'package:mobile/features/hangly_scene/presentation/hangly_scene_page.dart';

void main() {
  testWidgets('HanglyScenePage loads immediately with rope and charm', (WidgetTester tester) async {
    final storage = SettingsStorage();

    await tester.pumpWidget(HanglyApp(storage: storage));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify scene page is rendered
    expect(find.byType(HanglyScenePage), findsOneWidget);

    // Verify settings button and library button exist
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.collections_bookmark_outlined), findsOneWidget);

    // Verify default charm name is displayed
    expect(find.text('Nazar boncuğu'), findsOneWidget);
  });
}
