import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/charm.dart';

class CharmWidget extends StatelessWidget {
  final Charm charm;
  final BoxFit fit;

  const CharmWidget({super.key, required this.charm, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    if (charm.isCustom) {
      final file = File(charm.assetPath);
      if (charm.assetPath.toLowerCase().endsWith('.svg')) {
        return SvgPicture.file(file, fit: fit, placeholderBuilder: (_) => const CircularProgressIndicator.adaptive());
      } else {
        return Image.file(file, fit: fit, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image));
      }
    } else {
      if (charm.assetPath.toLowerCase().endsWith('.svg')) {
        return SvgPicture.asset(charm.assetPath, fit: fit, placeholderBuilder: (_) => const CircularProgressIndicator.adaptive());
      } else {
        return Image.asset(charm.assetPath, fit: fit, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image));
      }
    }
  }
}
