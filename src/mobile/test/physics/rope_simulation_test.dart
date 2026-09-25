import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/hangly_scene/physics/vec2.dart';
import 'package:mobile/features/hangly_scene/physics/rope_simulation.dart';
import 'package:mobile/features/hangly_scene/physics/rope_configuration.dart';

void main() {
  const anchor = Vec2(260, 15);
  const frame120 = 1.0 / 120.0;

  RopeSimulation makeRope() {
    final rope = RopeSimulation(
      configuration: RopeConfiguration.defaultValue,
      anchor: anchor,
    );
    rope.start();
    return rope;
  }

  void run(RopeSimulation rope, double seconds) {
    final steps = (seconds / frame120).toInt();
    for (int i = 0; i < steps; i++) {
      rope.step(frame120);
    }
  }

  group('RopeSimulation tests (Parity with C# suite)', () {
    test('Twenty segments means twenty-one nodes', () {
      final rope = makeRope();
      expect(rope.configuration.segmentCount, 20);
      expect(rope.points.length, 21);
    });

    test('The first node is pinned and the charm is the heaviest', () {
      final rope = makeRope();

      expect(rope.points[0].isPinned, isTrue);
      expect(rope.points[0].inverseMass, 0.0);

      // Charm node has smaller inverse mass than a plain rope node
      expect(rope.points[20].inverseMass < rope.points[10].inverseMass, isTrue);
      expect(rope.points[10].inverseMass, 1.0);
    });

    test('The anchor never moves, however hard the rope is driven', () {
      final rope = makeRope();
      rope.beginDrag(rope.points[20].position);
      rope.updateDrag(const Vec2(4000, -4000), const Vec2(9000, -9000));
      run(rope, 2.0);

      expect(rope.points[0].position, anchor);
    });

    test('The rope never stretches beyond its limit at rest', () {
      final rope = makeRope();
      run(rope, 5.0);

      expect(rope.measuredMaximumStretch <= rope.configuration.maxStretchRatio + 1e-6, isTrue);
    });

    test('The rest pose hangs straight down with no motion', () {
      final rope = makeRope();
      rope.resetToHanging();

      for (int i = 0; i < rope.points.length; i++) {
        expect(rope.points[i].displacement.magnitude, 0.0);
        expect((rope.points[i].position.x - anchor.x).abs() < 1e-6, isTrue);
      }
    });

    test('Releasing the charm preserves its momentum', () {
      final rope = makeRope();
      run(rope, 3.0);

      var position = rope.charmCenter;
      rope.beginDrag(position);

      const velocity = Vec2(600, 0);
      for (int tick = 0; tick < 30; tick++) {
        position += velocity * frame120;
        rope.updateDrag(position, velocity);
        rope.step(frame120);
      }

      rope.endDrag();
      final released = rope.charmCenter;
      rope.step(frame120);

      expect(rope.charmCenter.x > released.x, isTrue);
    });

    test('Push imparts velocity and wakes rope', () {
      final rope = makeRope();
      rope.resetToHanging();
      expect(rope.points.last.displacement.magnitude, 0.0);

      rope.push(1.0);
      expect(rope.isSleeping, isFalse);
      expect(rope.points.last.displacement.x.abs() > 0.001, isTrue);
    });

    test('Reachable target clamps excessive drag distance', () {
      final rope = makeRope();
      final target = rope.reachableTarget(const Vec2(10000, 10000));
      final dist = (target - anchor).magnitude;
      final maxReach = rope.configuration.totalLength * rope.configuration.maximumReachRatio;
      expect(dist <= maxReach + 1e-6, isTrue);
    });

    test('Only the charm can be grabbed', () {
      final rope = makeRope();
      run(rope, 3.0);

      expect(rope.canGrab(rope.charmCenter), isTrue);
      expect(rope.canGrab(rope.points[10].position), isFalse);
      expect(rope.canGrab(anchor), isFalse);
    });
  });
}
