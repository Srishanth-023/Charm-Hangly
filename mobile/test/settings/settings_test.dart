import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/settings.dart';
import 'package:mobile/core/models/rope_style.dart';

void main() {
  group('HanglySettings tests', () {
    test('Default settings are valid', () {
      const settings = HanglySettings.defaults;
      expect(settings.selectedCharmId, 'nazar');
      expect(settings.charmSize, 1.0);
      expect(settings.ropeLength, 1.0);
      expect(settings.ropeStyle, RopeStyle.thread);
      expect(settings.hapticsEnabled, isTrue);
      expect(settings.deviceMotionEnabled, isTrue);
      expect(settings.backgroundOverlayEnabled, isFalse);
    });

    test('Clamping works on numeric values', () {
      final settings = const HanglySettings().copyWith(
        charmSize: 5.0,
        ropeLength: 0.1,
        physicsStrength: 10.0,
      );
      expect(settings.charmSize, 2.0);
      expect(settings.ropeLength, 0.5);
      expect(settings.physicsStrength, 2.0);
    });

    test('JSON serialization round-trip', () {
      final original = const HanglySettings().copyWith(
        selectedCharmId: 'daruma',
        charmSize: 1.5,
        ropeLength: 1.2,
        ropeStyle: RopeStyle.neon,
        hapticsEnabled: false,
        deviceMotionEnabled: true,
        backgroundOverlayEnabled: true,
      );

      final json = original.toJson();
      final restored = HanglySettings.fromJson(json);

      expect(restored.selectedCharmId, 'daruma');
      expect(restored.charmSize, 1.5);
      expect(restored.ropeLength, 1.2);
      expect(restored.ropeStyle, RopeStyle.neon);
      expect(restored.hapticsEnabled, isFalse);
      expect(restored.deviceMotionEnabled, isTrue);
      expect(restored.backgroundOverlayEnabled, isTrue);
    });
  });
}
