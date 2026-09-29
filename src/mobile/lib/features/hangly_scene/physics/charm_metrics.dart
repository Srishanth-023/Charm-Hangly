import 'dart:math' as math;

/// Physical metrics of a charm as needed by the rope physics solver.
class CharmMetrics {
  final double mass;
  final double radiusRatio;
  final double knotInset;

  const CharmMetrics({
    required this.mass,
    required this.radiusRatio,
    required this.knotInset,
  });

  Map<String, dynamic> toJson() => {
        'mass': mass,
        'radiusRatio': radiusRatio,
        'knotInset': knotInset,
      };

  factory CharmMetrics.fromJson(Map<String, dynamic> json) {
    return CharmMetrics(
      mass: (json['mass'] as num).toDouble(),
      radiusRatio: (json['radiusRatio'] as num).toDouble(),
      knotInset: (json['knotInset'] as num).toDouble(),
    );
  }

  /// The shipped default, matching the plain bead.
  static const CharmMetrics defaultValue = CharmMetrics(
    mass: 2.6,
    radiusRatio: 0.126,
    knotInset: 0.90,
  );

  /// Scales charm mass and radius.
  CharmMetrics scaled(double size) {
    if ((size - 1.0).abs() < 1e-6) return this;
    return CharmMetrics(
      mass: mass * size,
      radiusRatio: radiusRatio * size,
      knotInset: knotInset,
    );
  }

  static CharmMetrics interpolate(CharmMetrics start, CharmMetrics end, double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    return CharmMetrics(
      mass: start.mass + (end.mass - start.mass) * clamped,
      radiusRatio: start.radiusRatio + (end.radiusRatio - start.radiusRatio) * clamped,
      knotInset: start.knotInset + (end.knotInset - start.knotInset) * clamped,
    );
  }
}

class CharmStack {
  static const int maximumCount = 3;
}
