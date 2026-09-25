import 'charm_metrics.dart';
import 'rope_configuration.dart';

class CharmSlot {
  final int node;
  final double radius;
  final double knotInset;
  final double mass;

  const CharmSlot({
    required this.node,
    required this.radius,
    required this.knotInset,
    required this.mass,
  });

  double get knotRadius => radius * knotInset;
}

class CharmStackLayout {
  final List<CharmSlot> slots;

  const CharmStackLayout(this.slots);

  static const CharmStackLayout empty = CharmStackLayout([]);

  int get count => slots.length;
  CharmSlot? get bottom => slots.isNotEmpty ? slots.last : null;

  static CharmStackLayout resolve(
    List<CharmMetrics> metrics,
    RopeConfiguration configuration,
  ) {
    if (metrics.isEmpty) return empty;

    final nodes = RopeLayout.attachments(metrics.length, configuration.segmentCount);
    final scale = RopeLayout.charmScale(metrics.length);
    final reference = configuration.charmReference;

    final slots = <CharmSlot>[];
    for (int i = 0; i < metrics.length; i++) {
      final charm = metrics[i];
      final node = nodes[i];
      final radius = charm.radiusRatio * reference * scale;
      slots.add(CharmSlot(
        node: node,
        radius: radius,
        knotInset: charm.knotInset,
        mass: charm.mass,
      ));
    }

    return CharmStackLayout(slots);
  }
}
