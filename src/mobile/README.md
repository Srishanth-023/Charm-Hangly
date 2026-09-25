# Hangly for Android

Hangly for Android is an interactive hanging desktop ornament application built with **Flutter**, **Dart**, and native **Android Kotlin**. It delivers the authentic Hangly Verlet rope simulation to Android devices with touch gestures, sensor integration, haptic feedback, and an optional persistent background overlay window.

## Product Architecture

The mobile app follows a clean, modular architecture:

```text
mobile/
  android/                     # Native Android project (Kotlin, Foreground Service, Overlay)
    app/src/main/
      kotlin/com/hangly/mobile/
        MainActivity.kt        # Flutter MethodChannel ('hangly/overlay') handler
        HanglyOverlayService.kt# Android Foreground Service with WindowManager overlay
      AndroidManifest.xml      # Required Android permissions & service declaration
  assets/
    charms/                    # 70+ authentic Hangly charm SVG assets across 13 collections
  lib/
    app/
      app.dart                 # Root MaterialApp widget
      theme.dart               # Dark/glass modern Hangly theme
    core/
      models/
        charm.dart             # Charm metadata and category definitions
        charm_catalog.dart     # Catalog of all built-in charms, categories, search
        rope_style.dart        # 9 rope styles with physics & visual properties
        settings.dart          # Local settings model with JSON serialization
      persistence/
        settings_storage.dart  # SharedPreferences-backed local storage
      platform/
        hangly_channel.dart    # Type-safe wrapper for 'hangly/overlay' MethodChannel
    features/
      hangly_scene/
        physics/
          vec2.dart            # 2D vector math
          rope_point.dart      # Verlet nodes with position history & mass
          rope_configuration.dart # Constants, canvas scale, and constraint budgets
          charm_stack_layout.dart # Resolved attachment nodes & radii
          rope_simulation.dart # Deterministic Verlet solver with relaxation & sleep
        rendering/
          rope_painter.dart    # Canvas CustomPainter for ropes, glows, and knots
        presentation/
          hangly_scene_page.dart # Interactive direct opening scene
      charm_library/
        presentation/
          charm_library_page.dart # Visual library, category chips, search, favorites
      settings/
        presentation/
          settings_page.dart   # Settings for size, length, styles, haptics, overlay
    services/
      background_service/      # Background overlay service manager
      haptics/                 # Haptics feedback service
      sensors/                 # Accelerometer device motion sway service
    main.dart                  # Application entry point
  test/
    physics/
      vector_math_test.dart    # Vec2 unit tests
      rope_simulation_test.dart# 100% parity tests against C# Hangly.Core.Tests
    settings/
      settings_test.dart       # Serialization, defaults, and validation tests
    widgets/
      hangly_scene_test.dart   # Scene launch and immediate rendering widget test
      settings_page_test.dart  # Settings controls & switches widget test
    integration/
      channel_test.dart        # MethodChannel mock contract tests
```

---

## Physics Engine

The rope physics engine in `lib/features/hangly_scene/physics/` is a direct, deterministic port of the portable C# solver from `src/Hangly.Core/Physics`:
- **Verlet Integration:** Fixed 240 Hz slices (`fixedTimeStep = 1/240s`) ensure identical motion across 60 Hz, 120 Hz, and 165 Hz displays.
- **Distance Constraint Relaxation:** Gauss-Seidel passes with stretch ceiling enforcement guarantee that the rope never unrealistically stretches or diverges.
- **Sleep & Power Management:** Automatically sleeps and freezes simulation ticks after the rope settles (`framesBeforeSleep = 60`), preserving battery and eliminating idle CPU usage.
- **Parity Tests:** The test suite in `test/physics/` directly mirrors the C# test suite in `tests/Hangly.Core.Tests/RopeSimulationTests.cs`.

---

## Android Permissions & Background Overlay Behavior

Hangly includes an optional **Always-On Overlay Mode** allowing your charm to hang above other applications while you use your phone.

### Platform Architecture
- **MethodChannel (`hangly/overlay`):** Flutter communicates with native Android code using explicit, typed message contracts.
- **Foreground Service (`HanglyOverlayService`):** Complies with modern Android service requirements using `specialUse` foreground service type and ongoing persistent notification.
- **Overlay Window (`WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY`):** Attaches a lightweight, interactive floating view with `FLAG_NOT_FOCUSABLE`. You can drag the charm anywhere across the screen.
- **Notification Controls:** The persistent foreground notification displays an immediate "Stop" action button to safely dismiss the charm and terminate the service at any time.
- **Screen Lifecycle:** A BroadcastReceiver listens for `ACTION_SCREEN_OFF` to pause drawing when the screen is locked, and `ACTION_SCREEN_ON` to resume.

### Permissions Required
1. `SYSTEM_ALERT_WINDOW`: Required to display floating content over other apps. The app displays a clear explanation dialog before launching the Android system permission screen.
2. `FOREGROUND_SERVICE` & `FOREGROUND_SERVICE_SPECIAL_USE`: Required by Android to run the ongoing overlay service.
3. `POST_NOTIFICATIONS`: Required on Android 13+ to display the ongoing notification with the quick stop action.
4. `VIBRATE`: Enables haptic feedback on touch and flick.

---

## Building & Testing

### Running Tests
From the `mobile/` directory:
```bash
flutter test
```

### Running Locally
To launch on a connected Android phone or emulator:
```bash
flutter run
```

### Building Release Artifacts
Use the top-level repository builder:
```bash
python builder.py --target mobile
```
Or directly via Flutter:
```bash
flutter build apk --release
flutter build appbundle --release
```
Outputs:
- APK: `build/mobile/apk/app-release.apk`
- AAB: `build/mobile/bundle/app-release.aab`
