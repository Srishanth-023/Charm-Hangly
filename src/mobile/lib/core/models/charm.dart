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
  final bool isCustom;

  const Charm({
    required this.id,
    required this.name,
    required this.category,
    required this.assetPath,
    required this.metrics,
    required this.primaryColor,
    this.description = '',
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'assetPath': assetPath,
        'metrics': metrics.toJson(),
        'primaryColor': primaryColor.value,
        'description': description,
        'isCustom': isCustom,
      };

  factory Charm.fromJson(Map<String, dynamic> json) {
    return Charm(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      assetPath: json['assetPath'] as String,
      metrics: CharmMetrics.fromJson(json['metrics'] as Map<String, dynamic>),
      primaryColor: Color(json['primaryColor'] as int),
      description: json['description'] as String? ?? '',
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

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
