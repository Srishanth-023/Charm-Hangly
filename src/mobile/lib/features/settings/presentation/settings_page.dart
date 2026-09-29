import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../core/models/rope_style.dart';
import '../../../core/models/settings.dart';
import '../../../core/persistence/settings_storage.dart';
import '../../../services/background_service/background_service_manager.dart';

class SettingsPage extends StatefulWidget {
  final HanglySettings initialSettings;
  final SettingsStorage storage;
  final BackgroundServiceManager? backgroundManager;

  const SettingsPage({
    super.key,
    required this.initialSettings,
    required this.storage,
    this.backgroundManager,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late HanglySettings _settings;
  late final BackgroundServiceManager _backgroundManager;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _backgroundManager = widget.backgroundManager ?? BackgroundServiceManager();
  }

  void _save(HanglySettings newSettings) async {
    setState(() => _settings = newSettings);
    await widget.storage.saveSettings(newSettings);
  }

  Future<void> _handleOverlayToggle(bool enable) async {
    if (enable) {
      final hasPerm = await _backgroundManager.hasOverlayPermission();
      if (!hasPerm) {
        if (!mounted) return;
        final bool? proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: HanglyTheme.surface,
            title: Text(
              'Display Over Other Apps',
              style: TextStyle(color: HanglyTheme.textPrimary),
            ),
            content: Text(
              'Android will open "Display over other apps":\n\n1. Scroll down to "Hangly" (under letter H)\n2. Tap "Hangly" and turn ON "Allow"\n3. Return here and your charm will float over all apps!',
              style: TextStyle(color: HanglyTheme.textSecondary, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: TextStyle(color: HanglyTheme.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: HanglyTheme.primary,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Grant Permission'),
              ),
            ],
          ),
        );

        if (proceed == true) {
          _save(_settings.copyWith(backgroundOverlayEnabled: true));
          await _backgroundManager.requestOverlayPermission();
        }
        return;
      }

      await _backgroundManager.enableOverlay(
        ropeLength: _settings.ropeLength * 140.0,
        charmRadius: _settings.charmSize * 26.0,
      );
      _save(_settings.copyWith(backgroundOverlayEnabled: true));
    } else {
      await _backgroundManager.disableOverlay();
      _save(_settings.copyWith(backgroundOverlayEnabled: false));
    }
  }

  void _resetDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HanglyTheme.surface,
        title: Text('Reset Settings?', style: TextStyle(color: HanglyTheme.textPrimary)),
        content: Text(
          'This will restore all rope lengths, sizes, and styles back to defaults.',
          style: TextStyle(color: HanglyTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: HanglyTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      const reset = HanglySettings.defaults;
      await widget.storage.resetSettings();
      setState(() => _settings = reset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _settings);
        }
      },
      child: Scaffold(
        backgroundColor: HanglyTheme.background,
        appBar: AppBar(
          title: Text('Settings'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _settings),
          ),
        ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildSectionHeader('Appearance & Rope'),
          _buildCard([
            _buildSliderTile(
              title: 'Charm Size',
              value: _settings.charmSize,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              displayFormat: '${(_settings.charmSize * 100).toInt()}%',
              onChanged: (val) => _save(_settings.copyWith(charmSize: val)),
            ),
            Divider(color: HanglyTheme.border, height: 1),
            _buildSliderTile(
              title: 'Rope Length',
              value: _settings.ropeLength,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              displayFormat: '${(_settings.ropeLength * 100).toInt()}%',
              onChanged: (val) => _save(_settings.copyWith(ropeLength: val)),
            ),
            Divider(color: HanglyTheme.border, height: 1),
            ListTile(
              title: Text('Rope Style', style: TextStyle(color: HanglyTheme.textPrimary)),
              subtitle: Text(
                RopeStyleTable.summaryOf(_settings.ropeStyle),
                style: TextStyle(color: HanglyTheme.textSecondary, fontSize: 12),
              ),
              trailing: DropdownButton<RopeStyle>(
                value: _settings.ropeStyle,
                dropdownColor: HanglyTheme.surfaceElevated,
                underline: const SizedBox(),
                items: RopeStyle.values.map((style) {
                  return DropdownMenuItem(
                    value: style,
                    child: Text(
                      RopeStyleTable.displayNameOf(style),
                      style: TextStyle(color: HanglyTheme.textPrimary),
                    ),
                  );
                }).toList(),
                onChanged: (newStyle) {
                  if (newStyle != null) {
                    _save(_settings.copyWith(ropeStyle: newStyle));
                  }
                },
              ),
            ),
          ]),

          const SizedBox(height: 16),
          _buildSectionHeader('Physics & Interaction'),
          _buildCard([
            _buildSliderTile(
              title: 'Motion Intensity',
              value: _settings.physicsStrength,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              displayFormat: '${(_settings.physicsStrength * 100).toInt()}%',
              onChanged: (val) => _save(_settings.copyWith(physicsStrength: val)),
            ),
            Divider(color: HanglyTheme.border, height: 1),
            SwitchListTile(
              title: Text('Haptic Feedback', style: TextStyle(color: HanglyTheme.textPrimary)),
              subtitle: Text('Vibrations on grab, flick, and impact',
                  style: TextStyle(color: HanglyTheme.textSecondary, fontSize: 12)),
              value: _settings.hapticsEnabled,
              onChanged: (val) => _save(_settings.copyWith(hapticsEnabled: val)),
            ),
            Divider(color: HanglyTheme.border, height: 1),
            SwitchListTile(
              title: Text('Device Motion (Sensors)', style: TextStyle(color: HanglyTheme.textPrimary)),
              subtitle: Text('Sway charm when tilting device',
                  style: TextStyle(color: HanglyTheme.textSecondary, fontSize: 12)),
              value: _settings.deviceMotionEnabled,
              onChanged: (val) => _save(_settings.copyWith(deviceMotionEnabled: val)),
            ),
          ]),

          const SizedBox(height: 16),
          _buildSectionHeader('Android Background & Overlay'),
          _buildCard([
            SwitchListTile(
              title: Text('Always-On Overlay Mode', style: TextStyle(color: HanglyTheme.textPrimary)),
              subtitle: Text(
                'Show charm floating over other apps via foreground service',
                style: TextStyle(color: HanglyTheme.textSecondary, fontSize: 12),
              ),
              value: _settings.backgroundOverlayEnabled,
              onChanged: _handleOverlayToggle,
            ),
            Divider(color: HanglyTheme.border, height: 1),
            ListTile(
              leading: Icon(Icons.power_settings_new, color: Colors.redAccent),
              title: Text('Kill Hangly Overlay', style: TextStyle(color: Colors.redAccent)),
              subtitle: Text('Completely stops the background service', style: TextStyle(color: HanglyTheme.textSecondary, fontSize: 12)),
              onTap: () async {
                await _backgroundManager.killOverlay();
                _save(_settings.copyWith(backgroundOverlayEnabled: false));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Hangly overlay background service killed.', style: TextStyle(color: HanglyTheme.textPrimary)),
                      backgroundColor: HanglyTheme.surfaceElevated,
                    ),
                  );
                }
              },
            ),
          ]),

          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(Icons.restore),
            label: Text('Reset to Defaults'),
            onPressed: _resetDefaults,
          ),

          const SizedBox(height: 32),
          _buildCard([
            ListTile(
              title: Text('Hangly for Android', style: TextStyle(color: HanglyTheme.textPrimary, fontWeight: FontWeight.bold)),
              subtitle: Text(
                'Version 1.0.0 (Release)\nBuilt with Flutter & .NET parity Verlet physics.\n\nPrivacy: Hangly has no accounts, no server tracking, and stores all preferences locally on your device.',
                style: TextStyle(color: HanglyTheme.textSecondary, fontSize: 12, height: 1.4),
              ),
            ),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: HanglyTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      color: HanglyTheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: HanglyTheme.border, width: 1),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayFormat,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: HanglyTheme.textPrimary)),
              Text(displayFormat, style: TextStyle(color: HanglyTheme.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
