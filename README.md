<div align="center">

  <img src="https://readme-typing-svg.demolab.com?font=Inter&weight=600&size=28&duration=3000&pause=1000&color=2D3748&center=true&vCenter=true&width=600&lines=Charm+Hangly;A+charm+hanging+on+your+screen;Push+it,+and+it+swings" alt="Typing SVG" />

  <p>Minimalist interactive physics charm for Windows and Android.</p>

  [![Build](https://img.shields.io/github/actions/workflow/status/SharanCreatedThis/Hangly-Windows/build.yml?style=flat-square&logo=github&color=3182CE)](https://github.com/SharanCreatedThis/Hangly-Windows/actions)
  [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square&color=E2E8F0&labelColor=2D3748)](LICENSE)

  <br/>
  
  <img src="assets/hangly-desktop.png" alt="Desktop Preview" width="650" style="border-radius: 8px;">

</div>

<br/>

### <img src="https://img.icons8.com/fluency-systems-filled/24/3182CE/info.png" width="18" valign="middle" /> Overview

Hangly is a physics-based interactive charm that hangs beautifully on your screen. Give it a push, and it swings with real-time Verlet physics before gracefully settling down. Available for both **Windows** (WinUI 3 & .NET 9) and **Android** (Flutter).

### <img src="https://img.icons8.com/fluency-systems-filled/24/3182CE/list.png" width="18" valign="middle" /> Features

* **Physics Engine:** Real-time interactive swinging mechanics.
* **Extensive Library:** Choose from over 70 unique charms across various collections.
* **Customization:** Multiple rope styles, sizes, and position configurations.
* **Personal Charms:** Import your own PNG, JPG, or SVG designs.
* **Unobtrusive:** Transparent, click-through overlay with extremely low background CPU usage.

<br/>

<div align="center">
  <img src="assets/hangly-library.png" alt="Library Preview" width="650" style="border-radius: 8px;">
</div>

<br/>

### <img src="https://img.icons8.com/fluency-systems-filled/24/3182CE/download.png" width="18" valign="middle" /> Downloads

Grab the latest automated installer files from the [Releases Page](https://github.com/SharanCreatedThis/Hangly-Windows/releases/latest). The current stable release is **v2.1.1**.

| Platform | Architecture | Binary |
| :--- | :--- | :--- |
| **Windows** | x64 (Intel/AMD) | `Hangly-win-x64-Setup.exe` |
| **Windows** | ARM64 (Snapdragon) | `Hangly-win-arm64-Setup.exe` |
| **Android** | Universal | `CharmHangly-Mobile.apk` (Upcoming) |

### <img src="https://img.icons8.com/fluency-systems-filled/24/3182CE/code.png" width="18" valign="middle" /> Building from Source

To compile the projects locally, you can use our built-in python script which elegantly handles both the C# desktop application and the Flutter mobile app.

**Prerequisites:**
* Python 3.8+
* .NET 9 SDK (For Windows Desktop)
* Flutter SDK (For Android)

```bash
git clone https://github.com/SharanCreatedThis/Hangly-Windows.git
cd Hangly-Windows

python builder.py
```

Follow the interactive prompt to build the `x64`, `arm64`, `windows`, or `mobile` architectures.

### <img src="https://img.icons8.com/fluency-systems-filled/24/3182CE/lock.png" width="18" valign="middle" /> Privacy & License

Hangly runs entirely offline. Optional analytics can be disabled in the settings. Released under the [MIT License](LICENSE). Please review [NOTICE.md](Reference/NOTICE.md) for specifics regarding artwork and branding rights.