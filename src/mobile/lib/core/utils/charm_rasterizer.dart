import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Helper to rasterize a charm asset (SVG, PNG, JPG) into a PNG byte array for native Android overlay display.
class CharmRasterizer {
  static final Map<String, Uint8List> _cache = {};

  /// Rasterizes an asset or file at [path] into PNG bytes.
  static Future<Uint8List?> rasterizeCharmAsset(
    String path, {
    double targetSize = 180.0,
    bool isCustom = false,
  }) async {
    if (_cache.containsKey(path)) {
      return _cache[path];
    }

    try {
      if (path.toLowerCase().endsWith('.svg')) {
        final loader = isCustom ? SvgFileLoader(File(path)) : SvgAssetLoader(path) as BytesLoader;
        final pictureInfo = await vg.loadPicture(loader, null);
        final srcWidth = pictureInfo.size.width;
        final srcHeight = pictureInfo.size.height;
        if (srcWidth <= 0 || srcHeight <= 0) return null;

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
        final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final bytes = byteData.buffer.asUint8List();
          _cache[path] = bytes;
          return bytes;
        }
      } else {
        // It's a PNG/JPG file or asset
        if (isCustom) {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            _cache[path] = bytes;
            return bytes;
          }
        } else {
          // It's a built-in asset, but all built-in charms are SVGs right now.
          // Just in case, load from root bundle
          // (Requires import 'package:flutter/services.dart'; but since it's not used, omit for now)
        }
      }
    } catch (e) {
      debugPrint('CharmRasterizer could not rasterize $path: $e');
    }
    return null;
  }

  /// Clears the rasterized cache if memory is constrained.
  static void clearCache() {
    _cache.clear();
  }
}
