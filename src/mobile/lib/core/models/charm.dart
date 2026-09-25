import 'package:flutter/material.dart';
import '../../features/hangly_scene/physics/charm_metrics.dart';

class Charm {
  final String id;
  final String name;
  final String category;
  final String assetPath;
  final CharmMetrics metrics;
  final Color primaryColor;
  final String description;

  const Charm({
    required this.id,
    required this.name,
    required this.category,
    required this.assetPath,
    required this.metrics,
    required this.primaryColor,
    this.description = '',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Charm && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class CharmCategory {
  final String id;
  final String name;
  final IconData icon;

  const CharmCategory({
    required this.id,
    required this.name,
    required this.icon,
  });
}
