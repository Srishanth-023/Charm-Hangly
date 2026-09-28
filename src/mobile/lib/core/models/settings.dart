import 'rope_style.dart';
import 'charm.dart';

class HanglySettings {
  final String selectedCharmId;
  final double charmSize;
  final double ropeLength;
  final RopeStyle ropeStyle;
  final bool hapticsEnabled;
  final bool deviceMotionEnabled;
  final bool backgroundOverlayEnabled;
  final double physicsStrength;
  final List<String> favourites;
  final List<Charm> customCharms;

  const HanglySettings({
    this.selectedCharmId = 'nazar',
    this.charmSize = 1.0,
    this.ropeLength = 1.0,
    this.ropeStyle = RopeStyle.thread,
    this.hapticsEnabled = true,
    this.deviceMotionEnabled = true,
    this.backgroundOverlayEnabled = true,
    this.physicsStrength = 1.0,
    this.favourites = const ['nazar', 'daruma', 'iron_man', 'messi'],
    this.customCharms = const [],
  });

  static const HanglySettings defaults = HanglySettings();

  HanglySettings copyWith({
    String? selectedCharmId,
    double? charmSize,
    double? ropeLength,
    RopeStyle? ropeStyle,
    bool? hapticsEnabled,
    bool? deviceMotionEnabled,
    bool? backgroundOverlayEnabled,
    double? physicsStrength,
    List<String>? favourites,
    List<Charm>? customCharms,
  }) {
    return HanglySettings(
      selectedCharmId: selectedCharmId ?? this.selectedCharmId,
      charmSize: (charmSize ?? this.charmSize).clamp(0.5, 2.0),
      ropeLength: (ropeLength ?? this.ropeLength).clamp(0.5, 2.0),
      ropeStyle: ropeStyle ?? this.ropeStyle,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      deviceMotionEnabled: deviceMotionEnabled ?? this.deviceMotionEnabled,
      backgroundOverlayEnabled:
          backgroundOverlayEnabled ?? this.backgroundOverlayEnabled,
      physicsStrength:
          (physicsStrength ?? this.physicsStrength).clamp(0.5, 2.0),
      favourites: favourites ?? this.favourites,
      customCharms: customCharms ?? this.customCharms,
    );
  }

  Map<String, dynamic> toJson() => {
        'selectedCharmId': selectedCharmId,
        'charmSize': charmSize,
        'ropeLength': ropeLength,
        'ropeStyle': ropeStyle.name,
        'hapticsEnabled': hapticsEnabled,
        'deviceMotionEnabled': deviceMotionEnabled,
        'backgroundOverlayEnabled': backgroundOverlayEnabled,
        'physicsStrength': physicsStrength,
        'favourites': favourites,
        'customCharms': customCharms.map((c) => c.toJson()).toList(),
      };

  factory HanglySettings.fromJson(Map<String, dynamic> json) {
    RopeStyle style = RopeStyle.thread;
    if (json['ropeStyle'] is String) {
      for (final s in RopeStyle.values) {
        if (s.name == json['ropeStyle']) {
          style = s;
          break;
        }
      }
    }

    final customCharmsJson = json['customCharms'] as List<dynamic>?;
    final List<Charm> parsedCustomCharms = customCharmsJson != null
        ? customCharmsJson
            .map((e) => Charm.fromJson(e as Map<String, dynamic>))
            .toList()
        : const [];

    return HanglySettings(
      selectedCharmId: json['selectedCharmId'] as String? ?? 'nazar',
      charmSize: (json['charmSize'] as num?)?.toDouble() ?? 1.0,
      ropeLength: (ropeLengthFromJson(json['ropeLength'])).clamp(0.5, 2.0),
      ropeStyle: style,
      hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
      deviceMotionEnabled: json['deviceMotionEnabled'] as bool? ?? true,
      backgroundOverlayEnabled:
          json['backgroundOverlayEnabled'] as bool? ?? true,
      physicsStrength: (json['physicsStrength'] as num?)?.toDouble() ?? 1.0,
      favourites: (json['favourites'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['nazar', 'daruma', 'iron_man', 'messi'],
      customCharms: parsedCustomCharms,
    );
  }

  static double ropeLengthFromJson(dynamic val) {
    if (val is num) return val.toDouble();
    return 1.0;
  }
}
