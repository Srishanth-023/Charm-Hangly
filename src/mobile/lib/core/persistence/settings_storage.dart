import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings.dart';

class SettingsStorage {
  static const String _settingsKey = 'hangly_user_settings';

  Future<HanglySettings> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_settingsKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
        return HanglySettings.fromJson(decoded);
      }
    } catch (_) {
      // Fallback to defaults on corrupt data
    }
    return HanglySettings.defaults;
  }

  Future<void> saveSettings(HanglySettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(settings.toJson());
      await prefs.setString(_settingsKey, jsonString);
    } catch (_) {
      // Best effort write
    }
  }

  Future<void> resetSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_settingsKey);
    } catch (_) {
      // Ignore
    }
  }
}
