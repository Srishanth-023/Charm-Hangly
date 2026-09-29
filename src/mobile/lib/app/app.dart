import 'package:flutter/material.dart';
import '../core/persistence/settings_storage.dart';
import '../features/hangly_scene/presentation/hangly_scene_page.dart';
import 'theme.dart';

class HanglyApp extends StatelessWidget {
  final SettingsStorage storage;

  const HanglyApp({
    super.key,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: HanglyTheme.themeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Charm Hangly',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: HanglyTheme.lightTheme,
          darkTheme: HanglyTheme.darkTheme,
          home: HanglyScenePage(storage: storage),
        );
      },
    );
  }
}
