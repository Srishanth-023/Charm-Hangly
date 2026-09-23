# Hangly Mobile App Ideas

Hangly is a strong candidate for a mobile adaptation because it already has three clear layers:

- **Portable domain logic:** rope physics, charm models, settings, and catalog data in `Hangly.Core`.
- **Platform-specific UI:** WinUI 3, Win2D, Windows overlays, tray integration, and Windows packaging in `Hangly.App`.
- **Assets and content:** charm artwork, collections, imported images, and customization flows.

The existing WinUI application should not be ported directly to mobile. Instead, preserve the product behavior and rebuild the mobile presentation around touch, sensors, and mobile lifecycle constraints.

## Product Directions

### 1. Pocket Hangly

A full-screen animated charm hangs from the top of the phone. Users can drag, flick, shake, and rotate the phone to interact with it.

- Touch-driven rope interaction
- Device-motion support for subtle movement
- Haptic feedback for impacts and releases
- Calm behavior when the app is idle

### 2. Home-Screen or Lock-Screen Charm

Allow users to display a selected charm outside the main app.

- iOS widgets or Live Activities
- Android home-screen widgets
- Daily message or changing rope style
- Lightweight static or limited animation for battery efficiency

The full physics simulation should run inside the app, while widgets provide a compact companion experience.

### 3. Personal Charm Collection

Bring the existing library experience to mobile.

- Browse collections
- Search and filter charms
- Mark favourites
- Create charm stacks
- Import a PNG, JPG, or SVG charm
- Share a charm design as an image or animation

### 4. Digital Good-Luck Companion

Let users assign charms to contexts such as study, travel, sleep, or work.

- Optional daily ritual
- Gentle reminders
- Context-specific charm presets
- No account required by default

This should remain playful and optional rather than becoming an intrusive habit system.

### 5. Interactive Customization Studio

Create a touch-friendly editor for building a hanging charm arrangement.

- Reorder charms by dragging
- Adjust charm size and rope length
- Select rope styles
- Adjust physics strength or damping
- Save named presets
- Preview changes immediately

### 6. Ambient Mode

A low-interaction screen where the charm moves gently in the background.

- Useful as a bedside or desk display
- Battery-aware simulation
- Reduced frame rate after the rope settles
- Optional sound or haptic feedback

### 7. Sharing and Deep Links

Let users share a charm stack without requiring accounts.

- Shareable charm-stack links
- QR codes for transferring a design
- Export as an image or short video
- Cloud sync can be added later if needed

## Suggested Mobile Architecture

Keep the mobile app divided into four parts:

```text
CharmDomain
  Models, catalog, settings, serialization

RopeEngine
  Deterministic physics, layout, collision and settling behavior

MobileRenderer
  Flutter CustomPainter or React Native Skia renderer

MobilePlatform
  Sensors, haptics, widgets, notifications, image import and sharing
```

The existing C# assembly cannot be referenced directly by Flutter or React Native. There are three practical options:

1. Rewrite the relatively contained rope solver in Dart or TypeScript.
2. Extract the solver into a C++ or Rust library and expose bindings to both platforms.
3. Keep the solver in .NET and use a .NET-based mobile framework such as .NET MAUI.

For a first release, rewriting the solver may be faster. For long-term behavioral parity between Windows and mobile, a shared native physics library is more robust.

## Flutter vs React Native

| Area | Flutter | React Native |
|---|---|---|
| Custom 2D rendering | Excellent with `CustomPainter`, Impeller, or Flutter Flame | Good with React Native Skia, but adds another rendering dependency |
| Physics animation | Natural for a continuously animated canvas | Works well, but animation must avoid unnecessary JavaScript-thread work |
| Consistent iOS and Android visuals | Strong consistency | More platform-native by default |
| Touch and gesture handling | Mature and straightforward | Mature, especially with Gesture Handler and Reanimated |
| Native APIs | Platform channels or plugins | Large native-module ecosystem |
| Reusing the C# core | Requires FFI or a rewrite | Requires JSI/native modules or a rewrite |
| Web or JavaScript team fit | Requires Dart | Excellent |
| Conventional app screens | Predictable and cohesive | Convenient for data-heavy screens and web-oriented products |
| Dependency surface | Usually controlled | Can become fragmented across navigation, animation, and rendering libraries |

## Recommendation

Choose **Flutter** for Hangly unless the team already has strong React and TypeScript expertise.

Flutter is a better fit for the product's central experience because Hangly is primarily a continuously animated, custom-rendered 2D scene. It provides:

- A consistent rendering model across iOS and Android
- Strong control over frame timing and gestures
- Straightforward custom drawing for ropes and charms
- Easier visual parity between platforms
- A natural foundation for ambient mode

Choose **React Native** when:

- The team is already deeply invested in React and TypeScript
- A web version is a major part of the roadmap
- The app will rely heavily on existing native modules
- The product is expected to become more data-driven than animation-driven

.NET MAUI is also worth evaluating because it offers the easiest C# reuse, but Flutter is likely to provide a more polished custom-rendering experience for Hangly with less platform-specific drawing work.

## Suggested First Mobile Release

A focused first release could include:

1. One interactive hanging charm.
2. Drag and flick gestures.
3. A small curated charm library.
4. Charm favourites and simple customization.
5. Importing a custom image.
6. Haptic feedback.
7. Ambient mode.
8. Local-only storage with no account requirement.

This would validate whether the physical interaction is compelling before investing in widgets, cloud sync, social sharing, or a large content catalog.
