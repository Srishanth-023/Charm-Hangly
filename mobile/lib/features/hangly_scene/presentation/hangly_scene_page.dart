import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/theme.dart';
import '../../../core/models/charm.dart';
import '../../../core/models/charm_catalog.dart';
import '../../../core/models/rope_style.dart';
import '../../../core/models/settings.dart';
import '../../../core/persistence/settings_storage.dart';
import '../../../services/haptics/haptics_service.dart';
import '../../../services/sensors/motion_sensor_service.dart';
import '../physics/rope_simulation.dart';
import '../physics/vec2.dart';
import '../rendering/rope_painter.dart';
import '../../charm_library/presentation/charm_library_page.dart';
import '../../settings/presentation/settings_page.dart';

class HanglyScenePage extends StatefulWidget {
  final SettingsStorage storage;

  const HanglyScenePage({
    super.key,
    required this.storage,
  });

  @override
  State<HanglyScenePage> createState() => _HanglyScenePageState();
}

class _HanglyScenePageState extends State<HanglyScenePage>
    with SingleTickerProviderStateMixin {
  late final RopeSimulation _simulation;
  late final HapticsService _haptics;
  late final MotionSensorService _sensorService;
  late Ticker _ticker;

  HanglySettings _settings = HanglySettings.defaults;
  Charm _currentCharm = CharmCatalog.defaultCharm;

  Duration _lastTick = Duration.zero;
  Vec2 _lastPointerPos = Vec2.zero;
  DateTime _lastPointerTime = DateTime.now();
  Vec2 _pointerVelocity = Vec2.zero;

  double _lastWidth = 0;
  double _lastHeight = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _simulation = RopeSimulation();
    _haptics = HapticsService();

    _sensorService = MotionSensorService(
      onSway: (speed) {
        if (_settings.deviceMotionEnabled) {
          _simulation.sway(speed * _settings.physicsStrength);
          if (!_ticker.isActive) {
            _ticker.start();
          }
        }
      },
    );

    _ticker = createTicker(_onTick);
    _loadSettingsAndStart();
  }

  Future<void> _loadSettingsAndStart() async {
    final loaded = await widget.storage.loadSettings();
    final charm = CharmCatalog.byId(loaded.selectedCharmId);

    if (mounted) {
      setState(() {
        _settings = loaded;
        _currentCharm = charm;
        _haptics.enabled = loaded.hapticsEnabled;
        _sensorService.updateEnabled(loaded.deviceMotionEnabled);
      });

      _applySettingsToSimulation();
      _simulation.start();
      _ticker.start();
      _sensorService.start();
      _initialized = true;
    }
  }

  void _applySettingsToSimulation() {
    _simulation.charmStackMetrics = [_currentCharm.metrics];
    _simulation.charmSize = _settings.charmSize;
    _simulation.ropeLength = _settings.ropeLength;

    if (_lastWidth > 0 && _lastHeight > 0) {
      _simulation.fit(
        canvasWidth: _lastWidth,
        canvasHeight: _lastHeight,
        charmSize: _settings.charmSize,
        ropeLength: _settings.ropeLength,
      );
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }

    final dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;

    if (dt > 0) {
      // Step simulation with delta time (clamped)
      _simulation.step(math.min(dt, 0.05) * _settings.physicsStrength);
      setState(() {});

      // Battery conscious: idle ticker if rope has settled completely and not dragging
      if (_simulation.isSleeping && !_simulation.isDragging) {
        _ticker.stop();
        _lastTick = Duration.zero;
      }
    }
  }

  void _wakeTicker() {
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
    _simulation.wake();
  }

  void _onPointerDown(PointerDownEvent event) {
    final touch = Vec2(event.localPosition.dx, event.localPosition.dy);
    _lastPointerPos = touch;
    _lastPointerTime = DateTime.now();
    _pointerVelocity = Vec2.zero;

    _wakeTicker();

    if (_simulation.canGrab(touch)) {
      _simulation.beginDrag(touch);
      _haptics.lightImpact();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final touch = Vec2(event.localPosition.dx, event.localPosition.dy);
    final now = DateTime.now();
    final elapsedSec = (now.difference(_lastPointerTime).inMicroseconds) / 1000000.0;

    if (elapsedSec > 0.001) {
      _pointerVelocity = (touch - _lastPointerPos) / elapsedSec;
      _lastPointerPos = touch;
      _lastPointerTime = now;
    }

    if (_simulation.isDragging) {
      _simulation.updateDrag(touch, _pointerVelocity);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_simulation.isDragging) {
      _simulation.endDrag();
      _haptics.mediumImpact();
    } else {
      // Tap on charm pushes / flicks it
      final touch = Vec2(event.localPosition.dx, event.localPosition.dy);
      if (_simulation.canGrab(touch)) {
        _simulation.push(1.0);
        _haptics.lightImpact();
      }
    }
  }

  Future<void> _openLibrary() async {
    _haptics.selectionClick();
    final Charm? selected = await Navigator.push<Charm>(
      context,
      MaterialPageRoute(
        builder: (context) => CharmLibraryPage(
          currentCharm: _currentCharm,
          settings: _settings,
          storage: widget.storage,
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _currentCharm = selected;
        _settings = _settings.copyWith(selectedCharmId: selected.id);
      });
      await widget.storage.saveSettings(_settings);
      _applySettingsToSimulation();
      _simulation.reset();
      _wakeTicker();
    }
  }

  Future<void> _openSettings() async {
    _haptics.selectionClick();
    final HanglySettings? updated = await Navigator.push<HanglySettings>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          initialSettings: _settings,
          storage: widget.storage,
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _settings = updated;
        _currentCharm = CharmCatalog.byId(updated.selectedCharmId);
        _haptics.enabled = updated.hapticsEnabled;
        _sensorService.updateEnabled(updated.deviceMotionEnabled);
      });

      _applySettingsToSimulation();
      _simulation.reset();
      _wakeTicker();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sensorService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HanglyTheme.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          if (width > 0 && height > 0 && (width != _lastWidth || height != _lastHeight)) {
            _lastWidth = width;
            _lastHeight = height;
            _simulation.fit(
              canvasWidth: width,
              canvasHeight: height,
              charmSize: _settings.charmSize,
              ropeLength: _settings.ropeLength,
            );
          }

          final charmNode = _simulation.points.isNotEmpty
              ? _simulation.points.last
              : null;
          final charmRadius = _simulation.charmLayout.slots.isNotEmpty
              ? _simulation.charmLayout.slots.last.radius
              : 30.0;
          final charmDiameter = charmRadius * 2.2;
          final orientation = _simulation.charmOrientation - (math.pi / 2.0);

          return Stack(
            children: [
              // 1. Interactive Gesture Detector over entire scene
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  child: Semantics(
                    label: 'Hangly rope and ${_currentCharm.name} charm. Drag or flick to swing.',
                    child: CustomPaint(
                      painter: RopePainter(
                        points: _simulation.points,
                        style: _settings.ropeStyle,
                        primaryColor: _currentCharm.primaryColor,
                      ),
                      size: Size(width, height),
                    ),
                  ),
                ),
              ),

              // 2. Render Charm SVG at bottom node
              if (charmNode != null)
                Positioned(
                  left: charmNode.position.x - (charmDiameter / 2.0),
                  top: charmNode.position.y - (charmDiameter / 2.0),
                  width: charmDiameter,
                  height: charmDiameter,
                  child: IgnorePointer(
                    child: Transform.rotate(
                      angle: orientation,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Subtle ambient halo
                          Container(
                            width: charmDiameter * 1.1,
                            height: charmDiameter * 1.1,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _currentCharm.primaryColor.withAlpha(50),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          // SVG Charm Artwork
                          SvgPicture.asset(
                            _currentCharm.assetPath,
                            width: charmDiameter,
                            height: charmDiameter,
                            fit: BoxFit.contain,
                            placeholderBuilder: (_) => const CircularProgressIndicator.adaptive(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 3. Quick Action Bar (Top Right)
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIconButton(
                      icon: Icons.collections_bookmark_outlined,
                      tooltip: 'Charm Library',
                      onPressed: _openLibrary,
                    ),
                    const SizedBox(width: 8),
                    _buildIconButton(
                      icon: Icons.settings_outlined,
                      tooltip: 'Settings',
                      onPressed: _openSettings,
                    ),
                  ],
                ),
              ),

              // 4. Charm Title and Category (Bottom overlay pill)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      _simulation.push(1.0);
                      _haptics.lightImpact();
                      _wakeTicker();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: HanglyTheme.surface.withAlpha(200),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: HanglyTheme.border,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentCharm.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _currentCharm.name,
                            style: const TextStyle(
                              color: HanglyTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: HanglyTheme.surface.withAlpha(200),
        shape: BoxShape.circle,
        border: Border.all(color: HanglyTheme.border, width: 1),
      ),
      child: IconButton(
        icon: Icon(icon, color: HanglyTheme.textPrimary, size: 22),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
