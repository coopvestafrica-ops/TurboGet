# TurboGet

TurboGet is an Android-first Flutter download manager with segmented parallel
downloads, pause / resume / cancel, a built-in scheduler, batch URL import,
YouTube quality selection, clipboard and share-sheet URL ingestion, and a
lightweight local auth model (super-admin, registered users, guests).

Ads are shown to guests via Google Mobile Ads; registered users and the
super-admin see the app ad-free.

## Features

- Segmented HTTP range downloads on Android (native Kotlin + OkHttp).
- Pause / resume / cancel wired end to end (Dart → `MethodChannel` →
  `DownloaderPlugin` → `SegmentedDownloader`).
- Batch URL import (paste or clipboard) and a scheduler that only runs
  downloads inside a chosen time window or when on Wi-Fi.
- YouTube / Vimeo / Dailymotion URL analysis via
  [`youtube_explode_dart`](https://pub.dev/packages/youtube_explode_dart)
  with a quality-selection dialog.
- First-run setup flow that creates the super-admin account with a salted
  SHA-256 password hash — no credentials live in source.
- Live theme switching (system / light / dark) that updates without
  restarting the app.
- Android share-target: share a URL from any app to TurboGet and it lands in
  the URL field.
- Cloud backup (currently simulated via `SharedPreferences`) of download
  history, and a cache-clear action that sweeps `getTemporaryDirectory()`
  and `getApplicationCacheDirectory()`.

## Project layout

```
lib/
  main.dart                       # entry point + home screen
  models/                         # data models (User, DownloadItem, ...)
  screens/                        # Material UI
    first_run_setup_screen.dart   # super-admin creation
    login_screen.dart             # username + password login
    admin_panel.dart              # user management
    settings_screen.dart          # theme, Wi-Fi-only, folder picker, cache
    download_history_screen.dart  # history + redownload
    batch_import_screen.dart      # paste many URLs at once
    file_browser_screen.dart      # browse downloaded files
  services/
    auth_service.dart             # salted SHA-256 + persisted session
    theme_service.dart            # ChangeNotifier theme mode
    download_manager.dart         # coordinates Dart-side state
    turbo_downloader.dart         # Dart implementation of segmented HTTP
    platform_analyzer.dart        # YoutubeExplode wrapper
    cloud_backup_service.dart     # simulated cloud backup
android/app/src/main/kotlin/
  com/example/turboget/MainActivity.kt       # registers the plugin + share intent
  com/example/downloader/DownloaderPlugin.kt # MethodChannel + EventChannel
  com/example/downloader/SegmentedDownloader.kt # range-request downloader
```

## Requirements

- Flutter 3.35.x (stable channel) with the Dart SDK it ships (3.9.x).
- Android Studio + Android SDK 34 for running on device / emulator.
- A device or emulator running Android 7.0+ (API 24).

## Getting started

```bash
flutter --version           # confirm Flutter 3.35.x
flutter pub get
flutter analyze             # should report "No issues found!"
flutter test                # widget + unit tests
flutter run                 # launches on the connected Android device
```

On first launch the app shows the **First-run setup** screen. Pick a username
and a password of at least 6 characters; that becomes the super-admin.

Subsequent launches go straight to the home screen. Tap the person icon in
the top-right to log in as a user, log in as a guest, or reach the admin
panel to create additional users.

## AdMob

The `android/app/src/main/AndroidManifest.xml` currently uses the Google
test AdMob app ID. Before shipping, replace it with your production AdMob
ID:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"/>
```

And update `lib/services/ad_manager.dart` with your real ad unit IDs.

## Android-specific notes

- The `DownloaderPlugin` is registered in `MainActivity.configureFlutterEngine`.
  If you add another plugin, register it the same way.
- `SegmentedDownloader` reserves the final file size with
  `RandomAccessFile.setLength` before launching four segment workers so
  each worker can seek into its byte range.
- Share sheets forward `ACTION_SEND` / `ACTION_VIEW` intents over the
  `com.example.turboget/share` channel. See `_initShareHandler` in
  `lib/main.dart` for the Dart side.

## CI

`.github/workflows/flutter-ci.yml` runs `flutter pub get`, `flutter analyze`,
a debug iOS simulator build, and a debug Android APK build on every push
and pull request against `main`.

## Testing

Plugin-backed flows (downloads, AdMob, SQLite) require an Android host, so
widget tests focus on the code that runs in isolation — the `User` model's
password hashing and the first-run setup form. Run them with:

```bash
flutter test
```

## License

See the repository for license information.
