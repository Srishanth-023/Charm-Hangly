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
    required String charmId,
    required String ropeStyle,
  }) async {
    final hasPerm = await hasOverlayPermission();
    if (!hasPerm) {
      await requestOverlayPermission();
      return false;
    }
    return _channel.startOverlayService(
      charmId: charmId,
      ropeStyle: ropeStyle,
    );
  }

  Future<bool> disableOverlay() async {
    return _channel.stopOverlayService();
  }

  Future<bool> isRunning() async {
    return _channel.isOverlayRunning();
  }
}
