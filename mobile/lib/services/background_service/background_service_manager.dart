import 'dart:typed_data';
import '../../core/platform/hangly_channel.dart';

class BackgroundServiceManager {
  final HanglyChannel _channel;

  BackgroundServiceManager({HanglyChannel? channel})
      : _channel = channel ?? HanglyChannel();

  Future<bool> hasOverlayPermission() async {
    return _channel.checkOverlayPermission();
  }

  Future<void> requestOverlayPermission() async {
    await _channel.requestOverlayPermission();
  }

  Future<bool> enableOverlay({
    Uint8List? charmBytes,
    String ropeColor = '#FFD700',
    double ropeLength = 140.0,
    double charmRadius = 26.0,
  }) async {
    final hasPerm = await hasOverlayPermission();
    if (!hasPerm) {
      await requestOverlayPermission();
      return false;
    }
    return _channel.startOverlayService(
      charmBytes: charmBytes,
      ropeColor: ropeColor,
      ropeLength: ropeLength,
      charmRadius: charmRadius,
    );
  }

  Future<bool> disableOverlay() async {
    return _channel.stopOverlayService();
  }

  Future<bool> isRunning() async {
    return _channel.isOverlayRunning();
  }
}
