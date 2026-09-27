# Ember App: In-App Update & Data Preservation Architecture

## 1. Overview
As the Ember project evolves, ensuring that end users receive updates smoothly and consistently is a top priority. When code is merged into the mainline branch, a system must be in place to seamlessly notify users of the update or install it automatically. 

Equally important is ensuring that **user data, algorithms, search behaviors, and local preferences remain perfectly intact** across these updates.

This document outlines the architecture for implementing an in-app update mechanism and the best practices for robust data persistence.

---

## 2. In-App Update Mechanisms

To distribute updates automatically to users outside of the Google Play Store, we have two primary architectural paths. It is recommended to use **Strategy B (GitHub Releases + upgrader)** for full app updates, coupled with **Strategy A (Shorebird)** for instant bug fixes.

### Strategy A: Over-The-Air (OTA) Updates via Shorebird
[Shorebird](https://shorebird.dev/) allows you to push Dart code changes instantly directly to user devices.
- **Workflow:** When a pull request is merged, a GitHub Actions workflow automatically runs `shorebird patch`.
- **User Experience:** The user opens the app, and the Shorebird engine silently downloads the new patch in the background. Upon the next app restart, they are running the latest code.
- **Best For:** UI tweaks, algorithm improvements, and critical bug fixes. Note that new native dependencies (Kotlin/Swift plugins) require a full build (Strategy B).

### Strategy B: Automated APK Distribution (Active Setup)
For major updates, we use a fully automated custom CI/CD pipeline integrated with GitHub.
- **Workflow:**
  1. A GitHub Actions CI/CD pipeline runs whenever a pull request is merged to `main`.
  2. It safely extracts the app version (e.g., `1.0.0`) dynamically from `pubspec.yaml`.
  3. It compiles the new Android release APK and commits it natively into the `Android_APK` folder on the `main` branch, allowing users to securely download `Ember_Latest.apk` directly from the repository.
  4. It simultaneously creates a GitHub Release tagged as `v1.0.0`.
- **User Experience:** An internal `UpdateChecker` using `package_info_plus` compares the local version against the latest GitHub API tag. If `app_version < remote_version`, the app presents an intuitive dialog prompting the user to download the update using `url_launcher`.

---

## 3. Preserving User Data and Algorithms

When an update is pushed, the user's "algorithm"—which encompasses their search history, cached playlists, listening habits, and app preferences—must be preserved entirely. 

### 3.1 OS-Level Data Persistence
By default, mobile operating systems (Android/iOS) **do not erase local App Data** during an update, provided:
1. The **Package Name** (e.g., `com.ember.app`) remains identical.
2. The **Signing Keystore** used to build the production application remains unchanged.

As long as these are consistent in our CI/CD pipeline, the OS will overwrite the binary while keeping the isolated storage directory intact.

### 3.2 Database Schema Migrations (Handling Structural Changes)
If an update includes modifications to the models storing user data (e.g., adding a new field to a saved Song model), we must handle the schema carefully to prevent the app from crashing when encountering old data structures.

- **For Hive (NoSQL):**
  - Never delete old Hive `TypeAdapters`. 
  - If a new field is added to a Hive model, ensure it has a `defaultValue` to gracefully load old cached data.
  - *Example:* Instead of crashing if a cached song lacks a `lyricsId`, the parser should smoothly assign it to `null`.
- **For SQLite / Isar / Drift (Relational):**
  - Implement versioned migrations. If we modify the database schema, we iterate the database version number and write an `onUpgrade` script (e.g., `ALTER TABLE songs ADD COLUMN lyrics_id TEXT;`).

### 3.3 Algorithm and Cache Invalidation
If the internal search algorithm or recommendation engine is heavily updated, the new code will inherently take over on launch.
- If the new algorithm requires a fresh start (e.g., the format of cached HTTP responses has changed), the app should check an internal `algorithmVersion` flag stored in SharedPreferences. 
- If `currentAppAlgorithm > storedAlgorithm`, the app can safely wipe outdated transient caches (like temporary search results) while intentionally preserving high-value user data like Playlists and Favorites.

---

## 4. Implementation Action Plan

1. **Setup Keystore & Secrets:** An explicit `ember.jks` release keystore governs the `com.ember.app` package identity inside `build.gradle.kts`.
2. **Configure CI/CD:** Our `.github/workflows/release.yml` automatically compiles `release` APKs on pushes to `main`. It physically commits the APK back to `Android_APK/Ember_Latest.apk` dynamically using the correct version from `pubspec.yaml` to prevent endless bloating.
3. **Integrate Version Checking Code:** An agile `UpdateChecker` script in `lib/utils` compares `package_info_plus`'s semantic runtime version strictly against the core GitHub release endpoint on application startup via `_MainLayoutState.initState()`.
4. **Implement Migration Base Classes:** Continue managing cache invalidations explicitly and design fail-safe schema updates for Hive.