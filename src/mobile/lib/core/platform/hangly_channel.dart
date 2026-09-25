import 'dart:typed_data';
import 'package:flutter/services.dart';

class HanglyChannel {
  static const MethodChannel _channel = MethodChannel('hangly/overlay');

  Future<bool> checkOverlayPermission() async {
    try {
      final bool? hasPermission =
          await _channel.invokeMethod<bool>('checkOverlayPermission');
      return hasPermission ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {
      // Platform error handling
    }
  }

  Future<bool> startOverlayService({
    Uint8List? charmBytes,
    String ropeColor = '#FFD700',
    double ropeLength = 140.0,
    double charmRadius = 26.0,
    bool hapticsEnabled = true,
  }) async {
    try {
      final bool? started = await _channel.invokeMethod<bool>(
        'startOverlayService',
        {
          'charmBytes': charmBytes,
          'ropeColor': ropeColor,
          'ropeLength': ropeLength,
          'charmRadius': charmRadius,
          'hapticsEnabled': hapticsEnabled,
        },
      );
      return started ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopOverlayService() async {
    try {
      final bool? stopped =
          await _channel.invokeMethod<bool>('stopOverlayService');
      return stopped ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isOverlayRunning() async {
    try {
      final bool? running =
          await _channel.invokeMethod<bool>('isOverlayRunning');
      return running ?? false;
    } catch (_) {
      return false;
    }
  }
}
