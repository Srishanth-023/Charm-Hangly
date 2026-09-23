import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

typedef SwayCallback = void Function(double horizontalSpeed);

class MotionSensorService {
  bool enabled = true;
  StreamSubscription<AccelerometerEvent>? _subscription;
  final SwayCallback onSway;
  double _lastX = 0.0;

  MotionSensorService({
    required this.onSway,
    this.enabled = true,
  });

  void start() {
    if (!enabled || _subscription != null) return;

    try {
      _subscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          if (!enabled) return;
          // event.x is acceleration in m/s^2 along X axis (tilting left/right)
          final deltaX = event.x - _lastX;
          _lastX = event.x;

          if (deltaX.abs() > 0.1) {
            // Apply sway proportionally
            onSway(-deltaX * 60.0);
          }
        },
        onError: (_) {
          // Graceful fallback if sensors are not supported
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
