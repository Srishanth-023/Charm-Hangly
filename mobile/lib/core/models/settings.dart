import 'rope_style.dart';

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

  const HanglySettings({
    this.selectedCharmId = 'nazar',
    this.charmSize = 1.0,
    this.ropeLength = 1.0,
    this.ropeStyle = RopeStyle.thread,
    this.hapticsEnabled = true,
    this.deviceMotionEnabled = true,
    this.backgroundOverlayEnabled = false,
    this.physicsStrength = 1.0,
    this.favourites = const ['nazar', 'daruma', 'iron_man', 'messi'],
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

    return HanglySettings(
      selectedCharmId: json['selectedCharmId'] as String? ?? 'nazar',
      charmSize: (json['charmSize'] as num?)?.toDouble() ?? 1.0,
      ropeLength: (ropeLengthFromJson(json['ropeLength'])).clamp(0.5, 2.0),
      ropeStyle: style,
      hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
      deviceMotionEnabled: json['deviceMotionEnabled'] as bool? ?? true,
      backgroundOverlayEnabled:
          json['backgroundOverlayEnabled'] as bool? ?? false,
      physicsStrength: (json['physicsStrength'] as num?)?.toDouble() ?? 1.0,
      favourites: (json['favourites'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['nazar', 'daruma', 'iron_man', 'messi'],
    );
  }

  static double ropeLengthFromJson(dynamic val) {
    if (val is num) return val.toDouble();
    return 1.0;
  }
}
