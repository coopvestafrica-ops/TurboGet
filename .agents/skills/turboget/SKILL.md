# TurboGet — working notes

Flutter download manager, Android-first. Dart SDK 3.9.x (pinned via
`environment.sdk: ^3.8.1`), Flutter 3.35.5 in CI.

## Local setup

```bash
flutter --version           # must be 3.35.x
flutter pub get
flutter analyze             # MUST be clean before pushing — CI gates on this
flutter test                # widget + unit smoke tests
```

Android builds require the usual Android SDK / NDK. iOS builds are CI-only
(macOS runner).

## Lint + test are required

CI (`.github/workflows/flutter-ci.yml`) runs `flutter pub get`, `flutter
analyze`, `flutter test`, `flutter build ios --simulator --no-codesign`, and
`flutter build apk --debug`. Any analyzer warning fails CI.

When editing Dart, prefer `debugPrint` over `print`, use
`Color.withValues(alpha: ...)` instead of the deprecated `withOpacity`, and
do not leak a `BuildContext` across an `await` (capture the
`ScaffoldMessenger` / `Navigator` before the `await`).

## Line endings

`pubspec.yaml`, Dart, Kotlin, and XML files in this repo use LF. If you see
`edit` tool failures reporting "String not found" despite the text being
present, the file may have gained CRLF line endings — normalize them with:

```bash
find lib android/app/src -type f \( -name "*.dart" -o -name "*.kt" -o -name "*.xml" \) \
  -exec sed -i 's/\r$//' {} +
```

## Architecture quick map

- `lib/main.dart` — app entry, home screen, clipboard watcher (SnackBar-based
  opt-in), share-intent handler, download queue UI.
- `lib/services/auth_service.dart` — singleton, salted SHA-256 passwords in
  `SharedPreferences`. `needsInitialSetup == true` routes to the first-run
  setup screen.
- `lib/services/theme_service.dart` — `ChangeNotifier`; wrap `MaterialApp`
  in a `ListenableBuilder` so theme changes propagate live.
- `lib/services/download_manager.dart` — single owner of in-progress
  downloads. `status` uses the string vocabulary `queued` / `downloading` /
  `paused` / `completed` / `failed` / `cancelled`.
- `lib/services/turbo_downloader.dart` — pure-Dart segmented downloader.
  Opens the output file with `FileMode.writeOnlyAppend` and seeks per
  segment; using `FileMode.write` truncates on every open.
- `lib/services/platform_analyzer.dart` — `YoutubeExplode` is **lazily
  created and reused**. Closing the client after every call (as earlier
  versions did) breaks every subsequent call. Call `dispose()` only when
  the analyzer is truly done.
- `android/app/src/main/kotlin/com/example/downloader/DownloaderPlugin.kt` —
  implements MethodChannel `com.example.downloader/methods` and EventChannel
  `com.example.downloader/events`. **Must be registered in
  `MainActivity.configureFlutterEngine`** via `flutterEngine.plugins.add(
  DownloaderPlugin())` or every Dart-side call fails with
  `MissingPluginException`.
- `SegmentedDownloader.Control { paused, cancelled, lock }` — shared between
  the plugin and each segment thread for cooperative pause/resume/cancel.

## Platform channels

| Channel                                | Direction      | Purpose                                    |
|----------------------------------------|----------------|--------------------------------------------|
| `com.example.downloader/methods`       | Dart → Kotlin  | `startDownload`, `pauseDownload`, `resumeDownload`, `cancelDownload` |
| `com.example.downloader/events`        | Kotlin → Dart  | Progress: `{id, progress, downloaded, total, status}` |
| `com.example.turboget/share`           | Kotlin → Dart  | `sharedUrl` (push) + `getInitialSharedUrl` (pull for cold-start) |

## Auth model

- `UserRole.superAdmin` — the one account created by the first-run flow.
- `UserRole.registeredUser` — created by the admin panel; ad-free.
- `UserRole.guest` — transient, shown ads. Guests are **not persisted**, so
  closing the app always returns to the logged-out state.

Never re-introduce a hardcoded super-admin password in source. The first-run
flow is the only supported way to bootstrap the admin.

## Testing strategy

Unit / widget tests under `test/` should exercise only pure Dart code and
widgets that don't depend on MethodChannel plugins. Anything that calls
`AdManager.initialize()`, `SharedPreferences.getInstance()` without prior
`SharedPreferences.setMockInitialValues`, or native downloads must run as
integration/manual tests on a device.
