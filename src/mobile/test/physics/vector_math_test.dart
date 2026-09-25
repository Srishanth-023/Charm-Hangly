import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/hangly_scene/physics/vec2.dart';

void main() {
  group('Vec2 tests', () {
    test('Zero vector properties', () {
      expect(Vec2.zero.x, 0.0);
      expect(Vec2.zero.y, 0.0);
      expect(Vec2.zero.magnitude, 0.0);
    });

    test('Addition, subtraction, and scaling', () {
      const a = Vec2(3, 4);
      const b = Vec2(1, 2);

      final sum = a + b;
      expect(sum.x, 4.0);
      expect(sum.y, 6.0);

      final diff = a - b;
      expect(diff.x, 2.0);
      expect(diff.y, 2.0);

      final scaled = a * 2.0;
      expect(scaled.x, 6.0);
      expect(scaled.y, 8.0);
      expect(scaled.magnitude, 10.0);
    });

    test('Distance and dot product', () {
      const a = Vec2(0, 0);
      const b = Vec2(3, 4);
      expect(a.distanceTo(b), 5.0);
      expect(a.dot(b), 0.0);
      expect(b.dot(b), 25.0);
    });

    test('Normalization and limited', () {
      const v = Vec2(10, 0);
      expect(v.normalized.x, 1.0);
      expect(v.normalized.y, 0.0);

      final limited = v.limited(5.0);
      expect(limited.magnitude, 5.0);
      expect(limited.x, 5.0);
    });

    test('Rotation', () {
      const v = Vec2(1, 0);
      final rotated = v.rotated(math.pi / 2);
      expect((rotated.x).abs() < 1e-6, isTrue);
      expect((rotated.y - 1.0).abs() < 1e-6, isTrue);
    });
  });
}
