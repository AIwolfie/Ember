# 🕯️ Ember Mobile (Android)

<p align="center">
  <a href="https://github.com/AIwolfie/Ember/releases/latest">
    <img src="https://img.shields.io/badge/⬇️_Download_Release-Ember.apk-3ddc84?style=for-the-badge&logo=android&logoColor=17120e" alt="Download Android APK"/>
  </a>
  <a href="https://github.com/AIwolfie/Ember/releases/latest">
    <img src="https://img.shields.io/badge/Release-v1.0.0_Ready-10b981?style=for-the-badge&logo=github&labelColor=2b231d" alt="GitHub Release"/>
  </a>
  <img src="https://img.shields.io/badge/Platform-Android_5.0+-2b231d?style=for-the-badge&logo=android&logoColor=3ddc84&labelColor=17120e" alt="Android Support"/>
  <img src="https://img.shields.io/badge/Engine-Flutter_3_+_Chaquopy-02569b?style=for-the-badge&logo=flutter&logoColor=white&labelColor=17120e" alt="Flutter & Chaquopy"/>
  <img src="https://img.shields.io/badge/License-MIT-d97706?style=for-the-badge&labelColor=17120e" alt="MIT License"/>
</p>

Ember Mobile is the companion Android music streaming client for Ember, built with Flutter and powered by Chaquopy Python. It brings the same warm, cozy desktop listening experience into your pocket with zero ads, high-fidelity audio streams, and intuitive gesture-based navigation.

---

## ✨ Key Features

- **📱 4-Tab Unified Navigation:**
  - **Home:** Personalized recommendations, mood chips, quick picks grid, and artist rows.
  - **Search:** Instant real-time search with fuzzy matching, artist clustering, and link detection.
  - **Library:** Complete collection management with interactive filter pills (`Playlists`, `Favorites`, `History`, `Downloads`), horizontal favorites carousel, and custom playlists.
  - **About:** Clean app details, features breakdown, open-source repository link, and developer credits.
- **🎨 5 Dynamic Theme Palettes:** Choose your vibe in Settings with instant live switching across `Amber` (default), `Emerald`, `Amethyst`, `Solar`, and `Rose`.
- **🎤 Synchronized Lyrics:** Real-time timestamped karaoke-style lyrics powered by LRCLIB.
- **🎛️ Equalizer & Audio Pipeline:** Built-in Android equalizer with customizable band controls.
- **🔗 Playlist URL Importer:** Paste YouTube Music, YouTube, or Spotify playlist links to stream or save to your local library.
- **🎧 Background Playback & SMTC:** Continuous playback with full Android system notifications, lockscreen controls, and Bluetooth headset media actions.
- **⚡ Offline-Ready Architecture:** SQLite local caching and optimized R8 shrinking to keep the APK agile and lightweight.

---

## 🚀 Download & Installation

### Option 1: Direct APK Download (Recommended)
1. Go to [Ember Releases](https://github.com/AIwolfie/Ember/releases/latest).
2. Download **`Ember.apk`**.
3. Open the APK on your Android phone and install.

---

## 🛠️ Build from Source

### Prerequisites
- [Flutter SDK](https://flutter.dev) (v3.13.4+)
- Android SDK (API 21+ / Android 5.0+)
- Java JDK 17

### Development Run
```bash
# 1. Clone & enter the folder
cd ember_flutter

# 2. Get dependencies
flutter pub get

# 3. Launch on a connected device
flutter run
```

### Packaging Release APK

```bash
# Standard universal release APK:
flutter build apk --release

# Output path:
# build/app/outputs/flutter-apk/app-release.apk
```

For smaller per-architecture split APKs (~25MB each):
```bash
flutter build apk --split-per-abi

# Output:
# app-armeabi-v7a-release.apk
# app-arm64-v8a-release.apk
# app-x86_64-release.apk
```

---

## 📦 Core Stack & Architecture

- **State Management:** `flutter_bloc` 9.1.1 + `provider`
- **Audio Playback:** `just_audio` + `just_audio_background` + `audio_session`
- **Python Bridge:** Native Chaquopy running guest catalog resolution and yt-dlp stream extraction
- **Local Storage:** `sqflite` + `path_provider`
- **Design & Typography:** Google Fonts (Inter), `shimmer`, `palette_generator`, `cached_network_image`

---

## 🤝 Creators & Contributors

- **Mayank Malaviya** — *Code Architect & Original Creator of Ember* · [aiwolfie.online](https://aiwolfie.online)
- **Kenil Ribadiya** — *Mobile App Architect & Developer* · [kenilribadiya.in](https://kenilribadiya.in/)

Distributed under the [MIT License](../LICENSE).
