import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:confetti/confetti.dart';

import '../../../app/theme.dart';
import '../../../core/models/charm.dart';
import '../../../core/models/charm_catalog.dart';
import '../../../core/models/rope_style.dart';
import '../../../core/models/settings.dart';
import '../../../core/persistence/settings_storage.dart';
import '../../../core/platform/hangly_channel.dart';
import '../../../core/utils/charm_rasterizer.dart';
import '../../../services/background_service/background_service_manager.dart';
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final RopeSimulation _simulation;
  late final HapticsService _haptics;
  late final MotionSensorService _sensorService;
  late final HanglyChannel _hanglyChannel;
  late Ticker _ticker;
  late final ConfettiController _confettiController;

  HanglySettings _settings = HanglySettings.defaults;
  Charm _currentCharm = CharmCatalog.defaultCharm;

  Duration _lastTick = Duration.zero;
  Vec2 _lastPointerPos = Vec2.zero;
  DateTime _lastPointerTime = DateTime.now();
  Vec2 _pointerVelocity = Vec2.zero;

  double _lastWidth = 0;
  double _lastHeight = 0;
  bool _initialized = false;

  bool _hasOverlayPermission = true;
  bool _dismissedPermissionBanner = false;
  bool _isOverlayActive = false;
  Uint8List? _precomputedCharmBytes;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addObserver(this);

    _simulation = RopeSimulation();
    _haptics = HapticsService();
    _hanglyChannel = HanglyChannel();

    _sensorService = MotionSensorService(
      onGravity: (gx, gy) {
        if (_settings.deviceMotionEnabled) {
          final strength = _settings.physicsStrength;
          final dirX = gx * strength;
          final dirY = (gy > 0) ? math.max(0.5, gy) : math.min(-0.5, gy);
          _simulation.setGravityDirection(Vec2(dirX, dirY));
          if (!_ticker.isActive) {
            _ticker.start();
          }
        }
      },
    );

    _ticker = createTicker(_onTick);

    // Hide any overlay that may have been left running from a previous session
    // (e.g. app crash, system restart). This prevents the two-charms bug.
    _hanglyChannel.stopOverlayService();

    _loadSettingsAndStart();
  }

  Future<void> _loadSettingsAndStart() async {
    final loaded = await widget.storage.loadSettings();
    final charm = CharmCatalog.byId(loaded.selectedCharmId);
    final hasPerm = await _hanglyChannel.checkOverlayPermission();

    if (mounted) {
      setState(() {
        _settings = loaded;
        _currentCharm = charm;
        _haptics.enabled = loaded.hapticsEnabled;
        _sensorService.updateEnabled(loaded.deviceMotionEnabled);
        _hasOverlayPermission = hasPerm;
      });

      _applySettingsToSimulation();
      _simulation.start();
      _ticker.start();
      _sensorService.start();
      _initialized = true;

      _precacheCurrentCharm();
      _confettiController.play();

      if (!hasPerm && !_dismissedPermissionBanner) {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted && !_hasOverlayPermission) {
            _requestPermissionWithHelp();
          }
        });
      }
    }
  }

  Future<void> _precacheCurrentCharm() async {
    try {
      final bytes = await CharmRasterizer.rasterizeSvgAsset(_currentCharm.assetPath);
      if (mounted && bytes != null) {
        _precomputedCharmBytes = bytes;
      }
    } catch (_) {}
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only show the overlay when the app is TRULY in the background (paused).
    // AppLifecycleState.inactive fires while the app is still partially visible
    // (e.g. pulling down the notification shade, swiping to app-switcher).
    // AppLifecycleState.hidden fires on Android 14 just before paused.
    // Triggering the overlay on those states causes the two-charms bug.
    if (state == AppLifecycleState.paused) {
      if (_settings.backgroundOverlayEnabled && !_isOverlayActive && !BackgroundServiceManager.isExiting) {
        _isOverlayActive = true;
        _launchBackgroundOverlay();
      }
    } else if (state == AppLifecycleState.resumed) {
      // ALWAYS hide the overlay when the user returns to Hangly regardless of
      // _isOverlayActive, in case the service was running from a previous session.
      _isOverlayActive = false;
      _hanglyChannel.stopOverlayService();
      _refreshPermissionState();
      _wakeTicker();
    }
  }

  Future<void> _refreshPermissionState() async {
    final hasPerm = await _hanglyChannel.checkOverlayPermission();
    if (mounted) {
      final justGranted = !_hasOverlayPermission && hasPerm;
      setState(() {
        _hasOverlayPermission = hasPerm;
      });
      if (justGranted) {
        if (!_settings.backgroundOverlayEnabled) {
          _settings = _settings.copyWith(backgroundOverlayEnabled: true);
          widget.storage.saveSettings(_settings);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: HanglyTheme.surfaceElevated,
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Floating charm active! Minimize Hangly to see it on your screen.',
                    style: TextStyle(color: HanglyTheme.textPrimary),
                  ),
                ),
              ],
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _launchBackgroundOverlay() {
    final bytes = _precomputedCharmBytes;

    final ropeColorHex = _settings.ropeStyle == RopeStyle.goldChain
        ? '#FFD700'
        : '#${_currentCharm.primaryColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    final ropeLen = (_settings.ropeLength * 135.0).clamp(50.0, 320.0);
    final radius = (_settings.charmSize * 25.0).clamp(12.0, 60.0);

    // Call native startOverlayService immediately without blocking on async work
    _hanglyChannel.startOverlayService(
      charmBytes: bytes,
      ropeColor: ropeColorHex,
      ropeLength: ropeLen,
      charmRadius: radius,
      hapticsEnabled: _settings.hapticsEnabled,
    );

    // If precomputation wasn't ready, resolve in background and refresh overlay
    if (bytes == null) {
      CharmRasterizer.rasterizeSvgAsset(_currentCharm.assetPath).then((resolved) {
        if (resolved != null && mounted) {
          _precomputedCharmBytes = resolved;
          if (_isOverlayActive) {
            _hanglyChannel.startOverlayService(
              charmBytes: resolved,
              ropeColor: ropeColorHex,
              ropeLength: ropeLen,
              charmRadius: radius,
              hapticsEnabled: _settings.hapticsEnabled,
            );
          }
        }
      });
    }
  }

  Future<void> _requestPermissionWithHelp() async {
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HanglyTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: HanglyTheme.primary),
            SizedBox(width: 8),
            Text('Enable Floating Charm', style: TextStyle(color: HanglyTheme.textPrimary, fontSize: 18)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Android will now open the "Display over other apps" list.\n',
              style: TextStyle(color: HanglyTheme.textSecondary, height: 1.4),
            ),
            Text(
              '1. Scroll down to "Charm Hangly" (under C)\n2. Tap "Charm Hangly" and turn ON "Allow"\n3. Return here and your charm will float over all apps!',
              style: TextStyle(color: HanglyTheme.textPrimary, fontWeight: FontWeight.w600, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: HanglyTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: HanglyTheme.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      if (!_settings.backgroundOverlayEnabled) {
        _settings = _settings.copyWith(backgroundOverlayEnabled: true);
        widget.storage.saveSettings(_settings);
      }
      await _hanglyChannel.requestOverlayPermission();
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
      _precacheCurrentCharm();
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

    final effective = updated ?? await widget.storage.loadSettings();

    if (mounted) {
      setState(() {
        _settings = effective;
        _currentCharm = CharmCatalog.byId(effective.selectedCharmId);
        _haptics.enabled = effective.hapticsEnabled;
        _sensorService.updateEnabled(effective.deviceMotionEnabled);
      });

      _applySettingsToSimulation();
      _simulation.reset();
      _wakeTicker();
      _refreshPermissionState();
      _precacheCurrentCharm();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    WidgetsBinding.instance.removeObserver(this);
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
          // Android overlay uses radius = _settings.charmSize * 25.0, so diameter is 50.0
          final charmDiameter = _settings.charmSize * 50.0;
          final orientation = _simulation.charmOrientation - (math.pi / 2.0);

          return Stack(
            children: [
              // 0. Ambient Background Logo
              Positioned.fill(
                child: Center(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.1, // Reduced transparency to match UI
                      child: Image.asset(
                        'assets/images/mobile-icon.png',
                        width: 250,
                        height: 250,
                      ),
                    ),
                  ),
                ),
              ),

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

              // 3. Quick Action Bar (Top Left, balanced with top-right charm)
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16,
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

              // 4. Permission Banner (Floating Charm mode prompt)
              if (!_hasOverlayPermission && !_dismissedPermissionBanner)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 60,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: HanglyTheme.surfaceElevated.withAlpha(240),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: HanglyTheme.primary.withAlpha(120), width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: HanglyTheme.primary.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: HanglyTheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Float Over Other Apps',
                                style: TextStyle(
                                  color: HanglyTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Allow permission so your charm follows you when minimized!',
                                style: TextStyle(
                                  color: HanglyTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HanglyTheme.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: const Size(60, 32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _requestPermissionWithHelp,
                          child: const Text('Enable', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: HanglyTheme.textSecondary, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _dismissedPermissionBanner = true;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

              // 5. Charm Title and Category (Bottom overlay pill)
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

              // 6. Quit button (Bottom right)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                right: 16,
                child: _buildIconButton(
                  icon: Icons.power_settings_new,
                  tooltip: 'Close Application Entirely',
                  onPressed: () {
                    BackgroundServiceManager.isExiting = true;
                    _hanglyChannel.killOverlayService();
                    SystemNavigator.pop();
                  },
                ),
              ),

              // 7. Confetti Popper (Falls from top center)
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: math.pi / 2, // Straight down
                  maxBlastForce: 25, // Fall speed
                  minBlastForce: 10,
                  emissionFrequency: 0.05,
                  numberOfParticles: 25,
                  gravity: 0.2,
                  colors: const [
                    Colors.red,
                    Colors.blue,
                    Colors.green,
                    Colors.yellow,
                    Colors.purple,
                    Colors.orange,
                  ],
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
