import 'package:flutter/services.dart';

class HapticsService {
  bool enabled = true;

  HapticsService({this.enabled = true});

  void lightImpact() {
    if (!enabled) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  void mediumImpact() {
    if (!enabled) return;
    try {
      HapticFeedback.vibrate();
    } catch (_) {}
  }

  void selectionClick() {
    if (!enabled) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
