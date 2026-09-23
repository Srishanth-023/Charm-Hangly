import 'package:flutter/material.dart';

enum RopeStyle {
  thread,
  leather,
  goldChain,
  silverChain,
  neon,
  spiderThread,
  midnightCord,
  templeThread,
  silverCord,
}

class RopePhysicsProfile {
  final double gravityScale;
  final double damping;
  final double maxStretchRatio;
  final int constraintIterations;
  final int stretchPasses;
  final double charmMassScale;

  const RopePhysicsProfile({
    required this.gravityScale,
    required this.damping,
    required this.maxStretchRatio,
    required this.constraintIterations,
    required this.stretchPasses,
    required this.charmMassScale,
  });
}

class RopeStyleTable {
  static const RopeStyle defaultStyle = RopeStyle.thread;
  static const RopeStyle shipped = RopeStyle.spiderThread;
  static const RopeStyle firstRun = RopeStyle.goldChain;

  static const List<RopeStyle> all = RopeStyle.values;

  static RopePhysicsProfile physicsOf(RopeStyle style) {
    switch (style) {
      case RopeStyle.thread:
        return const RopePhysicsProfile(
          gravityScale: 1.0,
          damping: 0.999,
          maxStretchRatio: 1.02,
          constraintIterations: 256,
          stretchPasses: 256,
          charmMassScale: 1.0,
        );
      case RopeStyle.leather:
        return const RopePhysicsProfile(
          gravityScale: 1.08,
          damping: 0.9955,
          maxStretchRatio: 1.006,
          constraintIterations: 288,
          stretchPasses: 288,
          charmMassScale: 1.05,
        );
      case RopeStyle.goldChain:
        return const RopePhysicsProfile(
          gravityScale: 0.72,
          damping: 0.9992,
          maxStretchRatio: 1.004,
          constraintIterations: 320,
          stretchPasses: 320,
          charmMassScale: 1.40,
        );
      case RopeStyle.silverChain:
        return const RopePhysicsProfile(
          gravityScale: 0.84,
          damping: 0.9988,
          maxStretchRatio: 1.005,
          constraintIterations: 320,
          stretchPasses: 320,
          charmMassScale: 1.25,
        );
      case RopeStyle.neon:
        return const RopePhysicsProfile(
          gravityScale: 1.22,
          damping: 0.9997,
          maxStretchRatio: 1.03,
          constraintIterations: 224,
          stretchPasses: 224,
          charmMassScale: 0.78,
        );
      case RopeStyle.spiderThread:
        return const RopePhysicsProfile(
          gravityScale: 1.16,
          damping: 0.9996,
          maxStretchRatio: 1.004,
          constraintIterations: 336,
          stretchPasses: 336,
          charmMassScale: 0.80,
        );
      case RopeStyle.midnightCord:
        return const RopePhysicsProfile(
          gravityScale: 0.78,
          damping: 0.9986,
          maxStretchRatio: 1.007,
          constraintIterations: 304,
          stretchPasses: 304,
          charmMassScale: 1.32,
        );
      case RopeStyle.templeThread:
        return const RopePhysicsProfile(
          gravityScale: 1.04,
          damping: 0.9982,
          maxStretchRatio: 1.026,
          constraintIterations: 232,
          stretchPasses: 232,
          charmMassScale: 0.92,
        );
      case RopeStyle.silverCord:
        return const RopePhysicsProfile(
          gravityScale: 0.94,
          damping: 0.9990,
          maxStretchRatio: 1.009,
          constraintIterations: 272,
          stretchPasses: 272,
          charmMassScale: 1.08,
        );
    }
  }

  static String displayNameOf(RopeStyle style) {
    switch (style) {
      case RopeStyle.thread:
        return 'Thread';
      case RopeStyle.leather:
        return 'Leather';
      case RopeStyle.goldChain:
        return 'Gold Chain';
      case RopeStyle.silverChain:
        return 'Silver Chain';
      case RopeStyle.neon:
        return 'Neon';
      case RopeStyle.spiderThread:
        return 'Spider Thread';
      case RopeStyle.midnightCord:
        return 'Midnight Cord';
      case RopeStyle.templeThread:
        return 'Temple Thread';
      case RopeStyle.silverCord:
        return 'Silver Cord';
    }
  }

  static String summaryOf(RopeStyle style) {
    switch (style) {
      case RopeStyle.thread:
        return 'Twisted gold. The cord Hangly has always used — light, quick, and quiet.';
      case RopeStyle.leather:
        return 'A flat braid. Stiffer than thread, and settles a little sooner.';
      case RopeStyle.goldChain:
        return 'Linked gold. The heaviest of the five, and the slowest to swing.';
      case RopeStyle.silverChain:
        return 'Linked silver. A chain\'s weight with a little more life in it.';
      case RopeStyle.neon:
        return 'A lit filament. The lightest cord and the most responsive.';
      case RopeStyle.spiderThread:
        return 'Spun silk. The thinnest cord of all, and stronger than anything its weight.';
      case RopeStyle.midnightCord:
        return 'A dark braid. Heavy, quiet, and slow to give a swing up.';
      case RopeStyle.templeThread:
        return 'Twisted cotton in saffron and vermilion. Soft, and it has some give.';
      case RopeStyle.silverCord:
        return 'Woven silver. A chain\'s shine with a cord\'s quickness.';
    }
  }

  static Color colorOf(RopeStyle style) {
    switch (style) {
      case RopeStyle.thread:
        return const Color(0xFFFFD700);
      case RopeStyle.leather:
        return const Color(0xFF8B4513);
      case RopeStyle.goldChain:
        return const Color(0xFFFFC107);
      case RopeStyle.silverChain:
        return const Color(0xFFC0C0C0);
      case RopeStyle.neon:
        return const Color(0xFF00E5FF);
      case RopeStyle.spiderThread:
        return const Color(0xFFE0E0E0);
      case RopeStyle.midnightCord:
        return const Color(0xFF263238);
      case RopeStyle.templeThread:
        return const Color(0xFFFF5722);
      case RopeStyle.silverCord:
        return const Color(0xFFB0BEC5);
    }
  }

  static double strokeWidthOf(RopeStyle style) {
    switch (style) {
      case RopeStyle.thread:
        return 2.5;
      case RopeStyle.leather:
        return 4.0;
      case RopeStyle.goldChain:
      case RopeStyle.silverChain:
        return 3.5;
      case RopeStyle.neon:
        return 2.5;
      case RopeStyle.spiderThread:
        return 1.8;
      case RopeStyle.midnightCord:
        return 3.8;
      case RopeStyle.templeThread:
        return 3.0;
      case RopeStyle.silverCord:
        return 3.2;
    }
  }
}
