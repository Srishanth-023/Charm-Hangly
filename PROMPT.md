# Hangly Android Mobile App Implementation Prompt

Use this document as the implementation brief for creating an Android mobile application for Hangly.

The existing product ideas and mobile exploration are documented in:

`D:\Dev\Projects\Charm-Hangly\MOBILE-APP-IDEAS.md`

Read that document first and use it as the product context. Apply the refinements and constraints below as the authoritative requirements when they differ from the exploratory ideas in that document.

## Product Goal

Create a downloadable Android application in Flutter that opens directly to an interactive Hangly scene:

- A charm is hanging from a rope when the app opens.
- The rope and charm can be interacted with through touch gestures.
- The physical behavior should feel natural and preserve the existing Hangly rope experience.
- The application should be visually polished, responsive, battery-conscious, and understandable to maintain.

The first mobile version is **Android-only**.

Do not implement iOS support, iOS widgets, iOS Live Activities, or a lock-screen experience in this phase.

## Core Requirements

### Android application

- Build the mobile application with Flutter and Dart.
- Target Android phones first, with layouts that can adapt to tablets where practical.
- Produce a downloadable Android artifact, preferably an APK for direct testing and an AAB for Play Store distribution.
- Use the existing Hangly charm artwork and preserve appropriate asset licensing boundaries.
- Keep the app usable without an account or mandatory server connection.
- Prefer local persistence for settings, favourites, selected charms, and custom configurations.

### Opening experience

When the application opens:

- Show the selected charm and rope immediately.
- Start the rope simulation without requiring the user to navigate through a setup screen.
- Restore the user's last selected charm configuration when possible.
- Provide a sensible default configuration on first launch.
- Ensure loading states never leave the main scene blank or visually broken.

### Interaction

Support:

- Dragging the charm or rope where appropriate.
- Flicking or releasing the charm with velocity.
- Natural settling and damping.
- Optional device motion interaction if it can be implemented without harming battery life or accessibility.
- Haptic feedback for meaningful interactions, with a setting to disable it.
- Pause or reduce simulation work when the rope is settled.

The physics should be deterministic enough to test. Avoid placing simulation logic directly inside widgets or rendering code.

### Background and minimized behavior

The charm and rope must remain available when the user minimizes the app or sends it to the background, subject to Android platform and user-permission rules.

Design this as an explicit Android feature rather than assuming a normal Flutter screen remains visible in the background:

- Use an Android foreground service for continued simulation/state maintenance when appropriate.
- Use an Android overlay window only where required to keep the charm visibly present above other applications.
- Request and explain the `SYSTEM_ALERT_WINDOW` permission before enabling an always-visible overlay.
- Provide a clear in-app toggle for the overlay/background behavior.
- Show a persistent foreground-service notification while Android requires one.
- Provide a way to stop the overlay and service from both the app and the notification.
- Handle Android battery-optimization restrictions carefully and explain any required user action.
- Respect Android lifecycle events, device rotation, screen locking, reboot behavior, and permission denial.
- Do not silently bypass platform restrictions.
- Do not claim that a normal background Flutter activity can continue rendering after it has been stopped.

The first version does not need to show the charm on the lock screen. When the device is locked, follow normal Android lifecycle behavior and suspend or stop visible rendering as appropriate.

The background/overlay feature must be implemented with Android-native code behind a small Flutter platform-channel boundary. Keep that boundary narrow and documented.

### Settings and charm configuration

The application must include a Settings screen. Charm configuration must be performed there rather than through an unexplained or hidden gesture-only interface.

Settings should include, at minimum:

- Selected charm.
- Charm size.
- Rope length.
- Rope style.
- Charm stack/order if multiple charms are supported.
- Physics strength, damping, or motion intensity.
- Haptics on/off.
- Device-motion interaction on/off.
- Ambient behavior or idle animation options.
- Background/overlay mode on/off.
- Start-on-launch preference where Android permits it.
- Reset to defaults.
- About, privacy, and licensing information.

Settings changes should update the preview or main scene predictably and persist locally. Validate numeric values and provide accessible labels and controls.

## Recommended Flutter Structure

Keep the project structure understandable, modular, and optimizable. Prefer feature-oriented organization with clear boundaries:

```text
mobile/
  android/
  assets/
    charms/
    images/
  lib/
    app/
      app.dart
      routes.dart
      theme.dart
    core/
      models/
      persistence/
      platform/
      result/
    features/
      hangly_scene/
        presentation/
        physics/
        rendering/
        gestures/
      charm_library/
        data/
        presentation/
      settings/
        data/
        presentation/
    services/
      background_service/
      haptics/
      sensors/
  test/
    physics/
    settings/
    widgets/
    integration/
  pubspec.yaml
```

This is a suggested structure, not a reason to create unnecessary layers. Keep each abstraction justified and small.

Required boundaries:

- **Domain/physics:** rope simulation, charm models, layout, settling, and configuration.
- **Rendering:** Flutter canvas/custom painter or an appropriate Flutter rendering package.
- **Presentation:** screens, widgets, navigation, and view state.
- **Persistence:** local settings and selected charm state.
- **Android integration:** foreground service, overlay permission, notification, sensors, haptics, and lifecycle handling.

Do not mix Android service code, persistence details, and physics calculations into a single large widget.

## Physics and Rendering Direction

Use the existing Hangly physics behavior as the source of truth where possible. The current repository contains the portable C# rope implementation in `src/Hangly.Core`.

Flutter cannot directly reference that .NET assembly. Choose and document one of these approaches:

1. Port the relatively contained solver to Dart with equivalent tests and behavior.
2. Extract a shared native solver into C++ or Rust and expose a narrow FFI interface.
3. Use generated or shared data contracts while keeping the Flutter solver implementation independent.

For an initial Android prototype, a Dart port is acceptable if it preserves the important behavior and has focused tests. Do not silently replace the physics with arbitrary animation.

The renderer should:

- Draw the rope and charms efficiently.
- Avoid rebuilding the entire widget tree every animation frame.
- Use a stable canvas size and coordinate model.
- Handle different screen sizes, density, cutouts, and orientation changes.
- Stop or reduce frame work when the scene is settled or the app is not visible.
- Keep imported or hostile SVG content sanitized before rendering.

## Builder Requirements

Update the repository's `builder.py` so running it interactively prompts the user to choose what to build:

- `mobile`
- `x64`
- `arm64`

The prompt should be clear and usable from a normal terminal. It should validate invalid input, allow retry or graceful cancellation, and report the selected target before starting work.

Target behavior:

- `mobile`: build and validate the Flutter Android application. Support a clearly documented debug/release choice if needed. Produce the expected APK/AAB output path.
- `x64`: preserve the existing Windows x64 test/publish behavior.
- `arm64`: preserve the existing Windows ARM64 test/publish behavior.

Maintain non-interactive command-line options where they are useful for CI and release automation. The interactive prompt must not make existing automated build usage impossible.

The builder should:

- Detect or clearly report missing Flutter, Dart, Android SDK, Java, and .NET prerequisites.
- Run the relevant tests for the selected target.
- Fail with actionable messages.
- Keep mobile outputs separate from Windows outputs.
- Avoid deleting unrelated build artifacts.
- Preserve the current Windows packaging and payload verification behavior.
- Use target-specific validation rather than applying Windows checks to Android output.

A possible output layout is:

```text
build/
  mobile/
    apk/
    bundle/
  win-x64/
  win-arm64/
  github-release/
```

Do not hard-code assumptions that only work on one developer machine.

## Testing Requirements

Add focused tests for:

- Rope physics stepping and settling.
- Drag and release behavior.
- Charm configuration validation.
- Settings persistence and reset behavior.
- Restoration of the last selected charm.
- Scene rendering at representative phone sizes.
- Android platform-channel message contracts.
- Background service start/stop state transitions.
- Overlay permission denied and granted paths.
- Builder target selection and invalid input handling.

Add an Android integration or smoke test for:

1. Launching the application.
2. Confirming that a rope and charm are visible.
3. Opening Settings.
4. Changing charm configuration.
5. Returning to the scene and observing the saved configuration.
6. Enabling and disabling background/overlay mode where the test environment permits.

Do not make tests depend on a physical device when a unit or contract test can cover the behavior.

## UX and Accessibility

- Make the interactive charm the first meaningful screen.
- Keep navigation simple: scene, charm library, and Settings are sufficient initially.
- Use readable controls and labels.
- Ensure controls have semantic descriptions for TalkBack.
- Provide non-motion alternatives for important actions.
- Respect reduced-motion preferences where available.
- Do not make background overlays surprising or difficult to disable.
- Explain special Android permissions in plain language before requesting them.

## Scope Exclusions for This Phase

Do not implement:

- iOS support.
- Lock-screen rendering.
- iOS widgets or Live Activities.
- Mandatory account creation.
- Cloud synchronization unless required later.
- A social network or public charm marketplace.
- Unrelated Windows refactors.

## Delivery Expectations

The implementation should leave behind:

- A clearly named Flutter Android project.
- A maintainable project structure.
- A documented build and run workflow.
- An updated `builder.py` with mobile, x64, and arm64 target selection.
- Focused automated tests.
- A short Android permissions and background-behavior explanation.
- No unexplained platform assumptions.

Before considering the work complete, verify the relevant build target, run the focused tests, inspect the generated artifact, and confirm that the Windows build paths remain intact.
