import 'dart:math' as math;
import 'vec2.dart';
import 'charm_metrics.dart';
import 'rope_configuration.dart';

/// One node of the rope used by the Verlet solver.
class RopePoint {
  Vec2 position;
  Vec2 previousPosition;
  double inverseMass;

  RopePoint({
    required this.position,
    Vec2? previousPosition,
    this.inverseMass = 1.0,
  }) : previousPosition = previousPosition ?? position;

  Vec2 get displacement => position - previousPosition;

  bool get isPinned => inverseMass == 0;

  void setVelocity(Vec2 velocity, double timeStep) {
    previousPosition = position - (velocity * timeStep);
  }

  /// Builds a straight chain of nodes hanging from [anchor] at [angle] from vertical.
  static List<RopePoint> chain({
    required RopeConfiguration configuration,
    required Vec2 anchor,
    required CharmMetrics charmMetrics,
    required double angle,
  }) {
    final direction = const Vec2(0, 1).rotated(angle);
    final lastIndex = configuration.pointCount - 1;
    final chain = <RopePoint>[];

    for (int index = 0; index <= lastIndex; index++) {
      double invMass;
      if (index == 0) {
        invMass = 0;
      } else if (index == lastIndex) {
        invMass = 1.0 / math.max(charmMetrics.mass, 0.0001);
      } else {
        invMass = 1.0;
      }

      final offset = direction * (index * configuration.segmentLength);
      chain.add(RopePoint(
        position: anchor + offset,
        inverseMass: invMass,
      ));
    }

    return chain;
  }
}
