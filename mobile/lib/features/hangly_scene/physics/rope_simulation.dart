import 'dart:math' as math;
import 'vec2.dart';
import 'rope_point.dart';
import 'charm_metrics.dart';
import 'rope_configuration.dart';
import 'charm_stack_layout.dart';

/// Hanging rope simulated with Verlet integration and position-based constraints.
class RopeSimulation {
  List<RopePoint> points = [];
  Vec2 anchor;
  RopeConfiguration configuration;
  List<CharmMetrics> charmStackMetrics;
  late CharmStackLayout charmLayout;

  double ropeLength = 1.0;
  double charmSize = 1.0;

  bool isRunning = false;
  bool isSleeping = false;
  int lastStepCount = 0;
  int _stillFrames = 0;
  double _accumulator = 0;

  int? dragIndex;
  Vec2 dragTarget = Vec2.zero;
  Vec2 dragVelocity = Vec2.zero;

  RopeSimulation({
    RopeConfiguration? configuration,
    Vec2? anchor,
    List<CharmMetrics>? charmStack,
  })  : configuration = configuration ?? RopeConfiguration.defaultValue,
        anchor = anchor ?? Vec2.zero,
        charmStackMetrics = charmStack ?? [CharmMetrics.defaultValue] {
    charmLayout = CharmStackLayout.resolve(charmStackMetrics, this.configuration);
    reset();
  }

  CharmMetrics get charmMetricsValue =>
      charmStackMetrics.isNotEmpty ? charmStackMetrics.last : CharmMetrics.defaultValue;

  bool get isDragging => dragIndex != null;

  Vec2 get charmCenter =>
      points.isNotEmpty ? points.last.position : Vec2.zero;

  double get charmOffsetFromAnchor =>
      points.isEmpty ? 0 : points.last.position.x - anchor.x;

  double get charmOrientation {
    if (points.length < 2) return math.pi / 2;
    final p1 = points[points.length - 2].position;
    final p2 = points.last.position;
    return math.atan2(p2.y - p1.y, p2.x - p1.x);
  }

  double get measuredMaximumStretch {
    if (points.length < 2) return 1.0;
    double maxRatio = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      final dist = points[i].position.distanceTo(points[i + 1].position);
      final ratio = dist / configuration.segmentLength;
      if (ratio > maxRatio) maxRatio = ratio;
    }
    return maxRatio;
  }

  void start() {
    if (isRunning) return;
    if (points.isEmpty) reset();
    _accumulator = 0;
    isRunning = true;
    wake();
  }

  void stop() {
    isRunning = false;
    _accumulator = 0;
  }

  void wake() {
    isSleeping = false;
    _stillFrames = 0;
  }

  void resetToHanging() => reset(0.0);

  void reset([double? angle]) {
    final startAngle = angle ?? configuration.initialAngle;
    points = RopePoint.chain(
      configuration: configuration,
      anchor: anchor,
      charmMetrics: charmMetricsValue,
      angle: startAngle,
    );
    _accumulator = 0;
    dragIndex = null;
    dragVelocity = Vec2.zero;
    lastStepCount = 0;
    wake();
  }

  Vec2 gravityDirection = const Vec2(0, 1);

  void setGravityDirection(Vec2 direction) {
    if (direction.magnitudeSquared < 1e-6) return;
    final norm = direction.normalized;
    if ((norm - gravityDirection).magnitudeSquared > 0.0004) {
      gravityDirection = norm;
      wake();
    }
  }

  void fit({
    required double canvasWidth,
    required double canvasHeight,
    double charmSize = 1.0,
    double ropeLength = 1.0,
  }) {
    this.charmSize = charmSize;
    this.ropeLength = ropeLength;

    final fitted = RopeConfiguration.fitted(
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      charmSize: charmSize,
      ropeLength: ropeLength,
    );

    final needsRebuild = points.length != fitted.pointCount || !isRunning;
    final lengthChanged = (configuration.segmentLength - fitted.segmentLength).abs() > 0.05;
    final previousAnchor = anchor;

    configuration = fitted;
    anchor = fitted.anchor(canvasWidth, canvasHeight);
    charmLayout = CharmStackLayout.resolve(charmStackMetrics, configuration);

    if (needsRebuild || lengthChanged) {
      reset();
    } else {
      final shift = anchor - previousAnchor;
      if (shift.magnitude > 1e-6) {
        for (int i = 0; i < points.length; i++) {
          points[i].position += shift;
          points[i].previousPosition += shift;
        }
      }
      wake();
    }
  }

  void step(double deltaTime) {
    if (!isRunning || deltaTime <= 0 || isSleeping) {
      lastStepCount = 0;
      return;
    }

    _accumulator = math.min(_accumulator + deltaTime, configuration.maxFrameDuration);
    final timeStep = configuration.fixedTimeStep;
    int taken = 0;
    while (_accumulator >= timeStep) {
      advance(timeStep);
      _accumulator -= timeStep;
      taken += 1;
    }

    lastStepCount = taken;
    updateSleepState();
  }

  void advance(double timeStep) {
    enforceAnchor();
    integrate(timeStep);
    driveDraggedPoint(timeStep);

    int relaxations = 0;
    double residual = double.infinity;
    while (relaxations < configuration.constraintIterations &&
        residual >= configuration.convergenceTolerance) {
      residual = math.max(solveDistanceConstraints(), separateCharms());
      relaxations += 1;
    }

    enforceMaximumStretch();
  }

  void enforceAnchor() {
    if (points.isEmpty) return;
    points[0].position = anchor;
    points[0].previousPosition = anchor;
  }

  void integrate(double timeStep) {
    final gravityMag = configuration.gravity * timeStep * timeStep;
    final gravityStep = gravityDirection * gravityMag;
    final damping = configuration.damping;
    final displacementLimit = configuration.maximumSpeed * timeStep;

    for (int index = 0; index < points.length; index++) {
      if (index == dragIndex || points[index].inverseMass <= 0) {
        continue;
      }

      final carried = (points[index].displacement * damping).limited(displacementLimit);
      points[index].previousPosition = points[index].position;
      points[index].position += carried + gravityStep;
    }
  }

  void driveDraggedPoint(double timeStep) {
    final index = dragIndex;
    if (index == null || index < 0 || index >= points.length) return;

    final current = points[index].position;
    final travelLimit = configuration.maximumSpeed * timeStep;
    points[index].position = current + (dragTarget - current).limited(travelLimit);
    points[index].setVelocity(dragVelocity, timeStep);
  }

  double solveDistanceConstraints() {
    final restLength = configuration.segmentLength;
    double largestCorrection = 0;
    for (int i = 0; i < points.length - 1; i++) {
      final corr = solveLink(i, i + 1, restLength);
      if (corr > largestCorrection) largestCorrection = corr;
    }
    return largestCorrection;
  }

  double solveLink(int indexA, int indexB, double restLength) {
    final inverseA = effectiveInverseMass(indexA);
    final inverseB = effectiveInverseMass(indexB);
    final totalInverseMass = inverseA + inverseB;
    if (totalInverseMass <= 0) return 0;

    final delta = points[indexB].position - points[indexA].position;
    final distance = delta.magnitude;
    if (distance <= 1e-12) return 0;

    final correction = delta * ((distance - restLength) / distance / totalInverseMass);
    points[indexA].position += correction * inverseA;
    points[indexB].position -= correction * inverseB;
    return math.max((correction * inverseA).magnitude, (correction * inverseB).magnitude);
  }

  double separateCharms() {
    final slots = charmLayout.slots;
    if (slots.length <= 1) return 0;

    double largestCorrection = 0;
    for (int first = 0; first < slots.length - 1; first++) {
      for (int second = first + 1; second < slots.length; second++) {
        final corr = separate(
          slots[first].node,
          slots[second].node,
          slots[first].radius + slots[second].radius,
        );
        if (corr > largestCorrection) largestCorrection = corr;
      }
    }
    return largestCorrection;
  }

  double separate(int lower, int upper, double minimum) {
    if (lower < 0 || lower >= points.length || upper < 0 || upper >= points.length) {
      return 0;
    }

    final inverseLower = effectiveInverseMass(lower);
    final inverseUpper = effectiveInverseMass(upper);
    final totalInverseMass = inverseLower + inverseUpper;
    if (totalInverseMass <= 0) return 0;

    final delta = points[upper].position - points[lower].position;
    final distance = delta.magnitude;
    if (distance >= minimum) return 0;

    final direction = distance > 1e-12 ? delta / distance : const Vec2(0, 1);
    final correction = direction * ((distance - minimum) / totalInverseMass);
    points[lower].position += correction * inverseLower;
    points[upper].position -= correction * inverseUpper;
    return math.max((correction * inverseLower).magnitude, (correction * inverseUpper).magnitude);
  }

  void enforceMaximumStretch() {
    final limit = configuration.segmentLength * configuration.maxStretchRatio;

    for (int pass = 0; pass < configuration.stretchPasses; pass++) {
      bool corrected = false;
      for (int index = 0; index < points.length - 1; index++) {
        if (clampLink(index, limit)) {
          corrected = true;
        }
      }
      if (!corrected) return;
    }
  }

  bool clampLink(int index, double limit) {
    final lower = index;
    final upper = index + 1;

    final inverseLower = effectiveInverseMass(lower);
    final inverseUpper = effectiveInverseMass(upper);
    final totalInverseMass = inverseLower + inverseUpper;
    if (totalInverseMass <= 0) return false;

    final delta = points[upper].position - points[lower].position;
    final distance = delta.magnitude;
    if (distance <= limit || distance <= 1e-12) return false;

    final correction = delta * ((distance - limit) / distance / totalInverseMass);
    points[lower].position += correction * inverseLower;
    points[upper].position -= correction * inverseUpper;
    return true;
  }

  double effectiveInverseMass(int index) =>
      index == dragIndex ? 0 : points[index].inverseMass;

  void updateSleepState() {
    if (dragIndex != null) {
      _stillFrames = 0;
      return;
    }

    final speedLimit = configuration.restSpeed * configuration.fixedTimeStep;
    bool moving = false;
    for (int i = 0; i < points.length; i++) {
      if (points[i].displacement.magnitude > speedLimit) {
        moving = true;
        break;
      }
    }

    if (moving) {
      _stillFrames = 0;
      return;
    }

    _stillFrames += 1;
    if (_stillFrames >= configuration.framesBeforeSleep) {
      isSleeping = true;
    }
  }

  void push([double direction = 1.0]) {
    if (points.length < 2 || direction == 0) return;

    final length = configuration.totalLength;
    final speed = math.sqrt(
      2 * configuration.gravity * length * (1.0 - math.cos(configuration.initialAngle)),
    );

    final charm = points.last;
    charm.previousPosition = charm.position -
        Vec2(direction.sign * speed * configuration.fixedTimeStep, 0);

    wake();
  }

  void sway(double horizontalSpeed) {
    if (points.length < 2 || horizontalSpeed.abs() < 0.001) return;

    for (int i = 1; i < points.length; i++) {
      final weight = i / points.length.toDouble();
      points[i].previousPosition +=
          Vec2(horizontalSpeed * configuration.fixedTimeStep * weight, 0);
    }

    wake();
  }

  void applyImpulse(Vec2 velocity, int index) {
    if (index < 0 || index >= points.length || points[index].inverseMass <= 0) return;
    points[index].previousPosition =
        points[index].position - (velocity * configuration.fixedTimeStep);
    wake();
  }

  bool canGrab(Vec2 location) => charmAt(location) != null;

  CharmSlot? charmAt(Vec2 location) {
    final idx = charmIndexAt(location);
    return idx != null ? charmLayout.slots[idx] : null;
  }

  int? charmIndexAt(Vec2 location) {
    int? best;
    double bestDistance = double.infinity;

    for (int index = charmLayout.slots.length - 1; index >= 0; index--) {
      final charm = charmLayout.slots[index];
      if (charm.node < 0 || charm.node >= points.length) continue;

      final distance = points[charm.node].position.distanceTo(location);
      if (distance > charm.radius + RopeLayout.grabPadding || distance >= bestDistance) {
        continue;
      }

      best = index;
      bestDistance = distance;
    }

    return best;
  }

  bool beginDrag(Vec2 location) {
    final charm = charmAt(location);
    if (charm == null) return false;

    dragIndex = charm.node;
    dragTarget = location;
    dragVelocity = Vec2.zero;
    wake();
    return true;
  }

  void updateDrag(Vec2 location, Vec2 velocity) {
    if (dragIndex == null) return;
    dragTarget = reachableTarget(location);
    dragVelocity = velocity.limited(configuration.maximumSpeed);
  }

  Vec2 reachableTarget(Vec2 location) {
    final heldNode = dragIndex ?? (points.length - 1);
    final held = heldNode * configuration.segmentLength;
    final reach = held * configuration.maximumReachRatio;
    final offset = location - anchor;
    final distance = offset.magnitude;
    if (distance <= reach || distance <= 1e-12) {
      return location;
    }
    return anchor + ((offset / distance) * reach);
  }

  void endDrag() {
    dragIndex = null;
    dragVelocity = Vec2.zero;
  }
}
