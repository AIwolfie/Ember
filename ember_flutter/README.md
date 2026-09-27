# Ember

Ember is a premium music application built with Flutter, designed with a modern, dynamic UI inspired by YouTube Music. It provides a robust, seamless audio experience with advanced features bridging seamlessly with a powerful Python backend.

## ✨ Key Features

- **Premium UI/UX:** A visually stunning interface featuring cinematic parallax headers, dynamic "Top Result" search cards, and a polished, gesture-driven bottom sheet transition for the full music player.
- **Intelligent Search:** Provides precise search capabilities, including accurate artist clustering, robust exact song matching, and fuzzy string matching for handling typos natively.
- **Synced Lyrics:** Integration with the LRCLIB API to serve accurate, real-time timestamped lyrics corresponding to your active playback.
- **Playlist Import:** Seamlessly import your favorite tracks and playlists from platforms like Spotify and YouTube Music directly via URL.
- **Optimized Android Performance:** Carefully tuned and optimized build configurations utilizing R8 shrinking, ProGuard rules, and specific ABI filters to maintain an agile Android release footprint (~50MB) without compromising functionality.

## 🛠 Tech Stack & Architecture

- **Frontend:** Flutter (`^3.13.4`) utilizing `flutter_bloc` and `provider` for state management.
- **Audio Engine:** `just_audio` and `just_audio_background` for reliable, background-capable media streaming and an immersive native media notification experience.
- **Dynamic Assets:** `cached_network_image`, `shimmer`, and `palette_generator` to generate dynamic background colors matching the album art.
- **Backend Bridge:** Relies on a Python backend architecture handling heavy metadata parsing, unified search logic, and fetching platform-specific audio streams to keep the mobile client nimble.

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `^3.13.4`
- Dart SDK
- Android SDK (min_sdk: 21)

### Installation

1. Navigate to the project directory:
   ```bash
   cd ember_flutter
   ```

2. Fetch the required dependencies:
   ```bash
   flutter pub get
   ```

3. Run the application:
   ```bash
   flutter run
   ```

## 📦 Core Dependencies
- audio operations: `just_audio`, `audio_session`, `just_audio_background`
- network/storage: `dio`, `sqflite`, `path_provider`
- UI mapping & design: `google_fonts`, `cupertino_icons`, `shimmer`
- state handling: `rxdart`, `equatable`, `easy_debounce`
