import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Helper to rasterize an SVG charm asset into a PNG byte array for native Android overlay display.
class CharmRasterizer {
  static final Map<String, Uint8List> _cache = {};

  /// Rasterizes an SVG asset at [assetPath] into PNG bytes.
  static Future<Uint8List?> rasterizeSvgAsset(
    String assetPath, {
    double targetSize = 180.0,
  }) async {
    if (_cache.containsKey(assetPath)) {
      return _cache[assetPath];
    }

    try {
      final pictureInfo = await vg.loadPicture(SvgAssetLoader(assetPath), null);
      final srcWidth = pictureInfo.size.width;
      final srcHeight = pictureInfo.size.height;
      if (srcWidth <= 0 || srcHeight <= 0) {
        return null;
      }

      final scale = math.min(targetSize / srcWidth, targetSize / srcHeight);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      final scaledW = srcWidth * scale;
      final scaledH = srcHeight * scale;
      final offsetX = (targetSize - scaledW) / 2.0;
      final offsetY = (targetSize - scaledH) / 2.0;

      canvas.translate(offsetX, offsetY);
      canvas.scale(scale, scale);
      canvas.drawPicture(pictureInfo.picture);

      final scaledPicture = recorder.endRecording();
      final ui.Image image = await scaledPicture.toImage(
        targetSize.toInt(),
        targetSize.toInt(),
      );
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        _cache[assetPath] = bytes;
        return bytes;
      }
    } catch (e) {
      debugPrint('CharmRasterizer could not rasterize $assetPath: $e');
    }
    return null;
  }

  /// Clears the rasterized cache if memory is constrained.
  static void clearCache() {
    _cache.clear();
  }
}
