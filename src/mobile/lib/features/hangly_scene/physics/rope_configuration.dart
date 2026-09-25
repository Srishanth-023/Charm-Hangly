import 'dart:math' as math;
import 'vec2.dart';
import 'charm_metrics.dart';

/// Tunable constants for the Verlet rope solver.
class RopeConfiguration {
  final int segmentCount;
  final double segmentLength;
  final double gravity;
  final double damping;
  final int constraintIterations;
  final int stretchPasses;
  final double convergenceTolerance;
  final double maxStretchRatio;
  final double fixedTimeStep;
  final double maxFrameDuration;
  final double maximumSpeed;
  final double maximumReachRatio;
  final double restSpeed;
  final int framesBeforeSleep;
  final double initialAngle;
  final double charmUnit;
  final double charmSizeScale;
  final double slackBelow;
  final double anchorHeight;

  const RopeConfiguration({
    this.segmentCount = 20,
    this.segmentLength = 11.0,
    this.gravity = 2000.0,
    this.damping = 0.999,
    this.constraintIterations = 256,
    this.stretchPasses = 256,
    this.convergenceTolerance = 0.05,
    this.maxStretchRatio = 1.02,
    this.fixedTimeStep = 1.0 / 240.0,
    this.maxFrameDuration = 0.1,
    this.maximumSpeed = 6000.0,
    this.maximumReachRatio = 0.98,
    this.restSpeed = 4.0,
    this.framesBeforeSleep = 60,
    this.initialAngle = 0.38,
    this.charmUnit = 0.0,
    this.charmSizeScale = 1.0,
    this.slackBelow = 0.0,
    this.anchorHeight = 0.0,
    this.anchorXRatio = 0.5,
  });

  final double anchorXRatio;

  int get pointCount => segmentCount + 1;
  double get totalLength => segmentCount * segmentLength;
  double get charmReference =>
      (charmUnit > 0 ? charmUnit : totalLength) * charmSizeScale;

  Vec2 anchor(double width, double height) =>
      anchorHeight > 0
          ? Vec2(width * anchorXRatio, anchorHeight)
          : Vec2(width * anchorXRatio, height * RopeLayout.anchorFraction);

  static const RopeConfiguration defaultValue = RopeConfiguration();

  RopeConfiguration copyWith({
    int? segmentCount,
    double? segmentLength,
    double? gravity,
    double? damping,
    int? constraintIterations,
    int? stretchPasses,
    double? convergenceTolerance,
    double? maxStretchRatio,
    double? fixedTimeStep,
    double? maxFrameDuration,
    double? maximumSpeed,
    double? maximumReachRatio,
    double? restSpeed,
    int? framesBeforeSleep,
    double? initialAngle,
    double? charmUnit,
    double? charmSizeScale,
    double? slackBelow,
    double? anchorHeight,
    double? anchorXRatio,
  }) {
    return RopeConfiguration(
      segmentCount: segmentCount ?? this.segmentCount,
      segmentLength: segmentLength ?? this.segmentLength,
      gravity: gravity ?? this.gravity,
      damping: damping ?? this.damping,
      constraintIterations: constraintIterations ?? this.constraintIterations,
      stretchPasses: stretchPasses ?? this.stretchPasses,
      convergenceTolerance: convergenceTolerance ?? this.convergenceTolerance,
      maxStretchRatio: maxStretchRatio ?? this.maxStretchRatio,
      fixedTimeStep: fixedTimeStep ?? this.fixedTimeStep,
      maxFrameDuration: maxFrameDuration ?? this.maxFrameDuration,
      maximumSpeed: maximumSpeed ?? this.maximumSpeed,
      maximumReachRatio: maximumReachRatio ?? this.maximumReachRatio,
      restSpeed: restSpeed ?? this.restSpeed,
      framesBeforeSleep: framesBeforeSleep ?? this.framesBeforeSleep,
      initialAngle: initialAngle ?? this.initialAngle,
      charmUnit: charmUnit ?? this.charmUnit,
      charmSizeScale: charmSizeScale ?? this.charmSizeScale,
      slackBelow: slackBelow ?? this.slackBelow,
      anchorHeight: anchorHeight ?? this.anchorHeight,
      anchorXRatio: anchorXRatio ?? this.anchorXRatio,
    );
  }

  /// Fits the rope to a canvas size in points.
  /// Keeps ropeLength and charmSize cleanly independent and directly scaled.
  /// Fixes anchor to the top right (between center and right edge at 0.75 * width).
  static RopeConfiguration fitted({
    required double canvasWidth,
    required double canvasHeight,
    double charmSize = 1.0,
    double ropeLength = 1.0,
  }) {
    // Calibrated base dimensions on mobile:
    // Base rope total length: 135.0 dp to match the 4th image (short rope)
    const baseRopeLength = 135.0;
    const baseCharmUnit = 50.0;
    const base = RopeConfiguration.defaultValue;

    final actualRopeLength = (baseRopeLength * ropeLength).clamp(50.0, canvasHeight * 0.9);
    final segLen = actualRopeLength / base.segmentCount;
    final charmUnit = baseCharmUnit;
    
    // Anchor exactly at the top edge of the screen (0.0) so it matches Android exactly
    const anchorH = 0.0;
    
    final totalLen = base.segmentCount * segLen;
    final slack = math.max(0.0, canvasHeight - anchorH - totalLen);

    return base.copyWith(
      charmUnit: charmUnit,
      charmSizeScale: charmSize,
      segmentLength: segLen,
      anchorHeight: anchorH,
      anchorXRatio: 0.75, // Fixed to top right (between center and right edge)
      slackBelow: slack,
    );
  }
}

class RopeLayout {
  static const double lengthFraction = 0.69;
  static const double anchorFraction = 0.01;
  static const double grabPadding = 15.0;
  static const double charmClearance = 0.45;
  static const double charmHaloExtent = 1.7;

  static double get tailFraction => 1.0 - anchorFraction - lengthFraction;

  static Vec2 anchorIn(double width, double height) =>
      Vec2(width * 0.75, height * anchorFraction);

  static List<int> attachments(int charmCount, int segmentCount) {
    final charms = charmCount.clamp(1, CharmStack.maximumCount);
    final nodes = List<int>.filled(charms, 0);
    for (int index = 1; index <= charms; index++) {
      if (index == charms) {
        nodes[index - 1] = segmentCount;
        continue;
      }
      final node = (segmentCount * index / charms).floor();
      nodes[index - 1] = math.max(
          index, math.min(segmentCount - (charms - index), node));
    }
    return nodes;
  }

  static double charmScale(int charmCount) {
    final count = charmCount.clamp(1, CharmStack.maximumCount);
    switch (count) {
      case 1:
        return 1.0;
      case 2:
        return 0.92;
      default:
        return 0.82;
    }
  }
}
