# ⚡ Ember Automatic OTA Update Pipeline

Ember Mobile utilizes **Shorebird Code Push** to deliver seamless, over-the-air (OTA) updates directly to users' devices without requiring manual APK downloads or app store re-installation.

---

## 🎯 How the Pipeline Works

```text
Developer changes Ember Dart/Flutter code
                  ↓
       git commit & git push main
                  ↓
          GitHub Actions CI/CD
                  ↓
  1. Code Formatting (dart format)
  2. Static Analysis (flutter analyze)
  3. Unit Tests (flutter test)
                  ↓
            Tests Pass?
             /        \
           YES         NO ──> Stop & Alert (No patch deployed)
            ↓
  shorebird patch android
            ↓
  Patch deployed to Shorebird Cloud
            ↓
  Users' Ember app checks in background
            ↓
  Patch downloads silently
            ↓
  Next app launch boots updated code
```

---

## 🚀 Daily Workflow: Normal Dart/Flutter Updates

When fixing bugs, tweaking UI, updating themes, or adjusting playback/navigation logic in Dart:

```bash
# 1. Make your changes in ember_flutter
git add .
git commit -m "fix(player): improve mini player seek progression"

# 2. Push to the main branch
git push origin main
```

**What happens next automatically:**
1. GitHub Actions detects changes in `ember_flutter/`.
2. The workflow verifies code formatting, runs static analysis, and executes all unit tests.
3. If all checks pass, it uses `shorebird patch android` to compile and distribute the patch to all existing users running that release.
4. When users open Ember, the patch downloads silently in the background without interrupting music playback, and takes effect on the next launch.

---

## 🛠️ One-Time Setup: Shorebird Account & GitHub Actions

To connect your GitHub repository to Shorebird:

### 1. Log in to Shorebird locally
Run in your terminal:
```bash
shorebird login
```
This opens your browser to authenticate with your Google account on [console.shorebird.dev](https://console.shorebird.dev).

### 2. App ID & Configuration (Completed)
Your Ember app is already initialized on Shorebird with:
- **App Name**: `Ember`
- **App ID**: `9120d38e-fba7-4b73-82a3-1775cf776425`
- Config file: [`ember_flutter/shorebird.yaml`](file:///D:/project/Ember/Ember/ember_flutter/shorebird.yaml)

### 3. Generate your CI Token
Run in your terminal:
```bash
shorebird login:ci
```
Or go to [console.shorebird.dev](https://console.shorebird.dev) → **Account Settings** → **CI Tokens** and generate your token.

### 4. Add Secret to GitHub
1. Go to your GitHub repository: `https://github.com/AIwolfie/Ember`
2. Navigate to **Settings** → **Secrets and variables** → **Actions**.
3. Click **New repository secret**.
4. Name: `SHOREBIRD_TOKEN`
5. Value: `<paste your token here>`
6. Click **Add secret**.

---

## 📦 Production Release 1.0.0+1 (Baseline Published)

The initial production release has been compiled and registered on Shorebird Cloud:
- **Release Version**: `1.0.0+1`
- **Flutter Version**: `3.47.5`
- **Engine Revision**: `ff900e7fba`
- **Android App Bundle**: `ember_flutter/build/app/outputs/bundle/release/app-release.aab`
- **Standalone Production APK**: `ember_flutter/build/app/outputs/flutter-apk/Ember.apk` (and `app-release.apk`)

Distribute this APK to your users or attach it to your GitHub Releases. Every future OTA patch created by GitHub Actions or local CLI will patch this baseline seamlessly.

---

## 🔧 Manual Patch Deployment (Local)

If you wish to deploy an OTA patch manually from your developer machine instead of GitHub Actions:

```bash
cd ember_flutter

# Dry-run validation (checks for native or asset differences without deploying)
shorebird patch android --dry-run

# Publish patch to all users
shorebird patch android
```

---

## ⚠️ OTA Limitations: When to Patch vs When to Release

Shorebird code push executes over the air at the Flutter engine / Dart VM level. Certain changes cannot be patched over the air and require a new binary release.

### ✅ Cleared for OTA Patches (`shorebird patch android`):
- Dart code modifications
- Flutter UI widgets, screens, animations, and layouts
- State management (`bloc`, `cubit`, `provider`)
- Business logic, search algorithms, API parsing, and formatting
- Bug fixes and optimizations in Dart code
- Adding or modifying pure Dart functions and helpers

### ❌ Requires a New Binary Release (`shorebird release android`):
- Modifying Android native code (`MainActivity.kt`, Java code)
- Adding or modifying Android permissions in `AndroidManifest.xml`
- Adding Flutter plugins that contain native Android/iOS code (e.g. plugins with Kotlin/Java/C++ code)
- Modifying Gradle configurations (`build.gradle.kts`, `settings.gradle.kts`)
- Updating the Flutter engine version
- Changing Android NDK / Chaquopy native libraries

> **Safety Guard**: Shorebird automatically detects native differences when running `shorebird patch android` and refuses to deploy an incompatible patch. Never bypass this with `--allow-native-diffs` unless you have thoroughly verified runtime safety.

---

## 📱 In-App Update Experience

1. **Automatic Background Check**:
   During app startup, `UpdateService.instance.initBackgroundUpdate()` queries Shorebird. If an update is detected, it downloads silently in the background while the user listens to music.
2. **Settings Screen**:
   Users can open **Settings** → **Updates** to:
   - See their current version and patch number (e.g. `Version 1.0.0 • Patch 2`).
   - Manually tap **[ Check for updates ]**.
   - Tap **[ Update now ]** to immediately download and stage a pending update.
