import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

typedef GravityCallback = void Function(double gx, double gy);
typedef SwayCallback = void Function(double horizontalSpeed);

class MotionSensorService {
  bool enabled = true;
  StreamSubscription<AccelerometerEvent>? _subscription;
  final GravityCallback onGravity;
  final SwayCallback? onSway;
  double _smoothGx = 0.0;
  double _smoothGy = 1.0;

  MotionSensorService({
    required this.onGravity,
    this.onSway,
    this.enabled = true,
  });

  void start() {
    if (!enabled || _subscription != null) return;

    try {
      _subscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          if (!enabled) return;

          // Apply deadzone to prevent hand jitter while holding still
          double targetX = event.x / 9.81;
          if (targetX.abs() < 0.06) {
            targetX = 0.0;
          } else {
            targetX = (targetX > 0) ? (targetX - 0.06) : (targetX + 0.06);
          }

          // Scale down sensitivity for calm, elegant sway
          targetX *= 0.35;

          final targetY = event.y / 9.81;

          // Smooth low-pass filter (0.10 for gentle, non-jarring tilt response)
          _smoothGx += (targetX - _smoothGx) * 0.10;
          _smoothGy += (targetY - _smoothGy) * 0.10;

          onGravity(_smoothGx, _smoothGy);

          // Support legacy onSway callback if provided
          if (onSway != null && targetX.abs() > 0.02) {
            onSway!(-targetX * 25.0);
          }
        },
        onError: (_) {
          stop();
        },
      );
    } catch (_) {
      // Ignored
    }
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  void updateEnabled(bool isEnabled) {
    enabled = isEnabled;
    if (enabled) {
      start();
    } else {
      stop();
    }
  }
}
