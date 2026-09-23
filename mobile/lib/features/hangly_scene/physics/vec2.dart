import 'dart:math' as math;

/// 2D vector with arithmetic and geometric operations for the Hangly Verlet solver.
class Vec2 {
  final double x;
  final double y;

  const Vec2(this.x, this.y);

  static const Vec2 zero = Vec2(0, 0);

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);
  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);
  Vec2 operator *(double scale) => Vec2(x * scale, y * scale);
  Vec2 operator /(double divisor) => Vec2(x / divisor, y / divisor);
  Vec2 operator -() => Vec2(-x, -y);

  double get magnitude => math.sqrt(x * x + y * y);
  double get magnitudeSquared => x * x + y * y;

  Vec2 get normalized {
    final len = magnitude;
    return len > 1e-12 ? this / len : Vec2.zero;
  }

  double distanceTo(Vec2 other) => (other - this).magnitude;

  double dot(Vec2 other) => x * other.x + y * other.y;

  /// Rotates this vector counter-clockwise by [radians].
  Vec2 rotated(double radians) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    return Vec2(x * c - y * s, x * s + y * c);
  }

  /// Clamps the vector's length to [maximum] while keeping direction.
  Vec2 limited(double maximum) {
    final len = magnitude;
    if (len <= maximum || len <= 1e-12) {
      return this;
    }
    return this * (maximum / len);
  }

  static Vec2 lerp(Vec2 a, Vec2 b, double t) {
    return Vec2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vec2 &&
          (x - other.x).abs() < 1e-12 &&
          (y - other.y).abs() < 1e-12;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '(${x.toStringAsFixed(4)}, ${y.toStringAsFixed(4)})';
}
