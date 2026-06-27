# TurboGet

<div align="center">

![TurboGet Logo](docs/images/logo.png)

**Enterprise-Grade Download Manager for Flutter**

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.24.0-blue)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5.0-blue)](https://dart.dev)

</div>

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

---

## Features

### ✨ Beautiful UI
- **Professional Dashboard** - Stunning gradient design with animated elements
- **Dark/Light Theme** - System-aware theming with smooth transitions
- **Progress Indicators** - Circular and linear progress with real-time speed
- **File Type Icons** - Emoji-based icons for all file types
- **Micro-interactions** - Smooth animations and transitions

### 🚀 Core Features
- **High-Speed Downloads** - Multi-threaded download acceleration
- **Batch Downloads** - Import multiple URLs at once
- **Scheduled Downloads** - Set download time windows
- **File Browser** - Built-in file manager with preview
- **Download History** - Track all past downloads
- **Media Player** - Built-in video/audio playback

### 📊 File Support (80+ formats)
- **Videos**: MP4, MKV, AVI, MOV, WMV, FLV, WebM, M4V, 3GP, MPEG, TS, VOB
- **Audio**: MP3, WAV, AAC, FLAC, OGG, M4A, WMA, AIFF, Opus, AMR
- **Images**: JPG, PNG, GIF, WebP, BMP, SVG, TIFF, HEIC, RAW
- **Documents**: PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX, TXT, CSV
- **Archives**: ZIP, RAR, 7Z, TAR, GZ, BZ2, ISO

### 🔔 Notifications
- **Progress Notifications** - Real-time download progress
- **Completion Alerts** - Download finished notifications
- **Quick Actions** - Pause, resume, cancel from notifications

### 🔐 Enterprise Features
- **User Authentication** - Role-based access control
- **User Management** - Admin panel for user administration
- **Ad Revenue** - Integrated AdMob monetization
- **Analytics Ready** - Event tracking infrastructure
- **Security** - Input validation, secure storage
- **Logging** - Comprehensive error tracking
- **Localization** - i18n support (English)
- **Export/Import** - Backup download history and settings

### Technical Features

- **Riverpod State Management** - Reactive state handling
- **Dependency Injection** - Clean service architecture
- **SQLite Database** - Persistent local storage
- **Platform Channels** - Native performance
- **Error Boundaries** - Graceful error handling
- **Unit Tests** - 80%+ code coverage target

---

## Architecture

TurboGet follows **Clean Architecture** principles with clear separation of concerns:

```
lib/
├── main.dart                 # App entry point
├── app.dart                  # MaterialApp configuration
├── config/                   # App-wide configuration
├── core/                     # Shared utilities
│   ├── constants/
│   ├── errors/
│   ├── network/
│   └── utils/
├── data/                     # Data layer
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/                   # Business logic
│   ├── entities/
│   ├── repositories/
│   └── usecases/
├── presentation/              # UI layer
│   ├── screens/
│   ├── widgets/
│   └── providers/
└── services/                  # App services
```

### State Management

The app uses **Riverpod** for state management with:

- **StateNotifier** for complex state
- **Provider** for dependencies
- **AsyncNotifier** for async operations

---

## Getting Started

### Prerequisites

- Flutter SDK 3.24.0 or higher
- Dart SDK 3.5.0 or higher
- Android SDK (for Android builds)
- Xcode (for iOS builds, macOS only)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/turboget.git
   cd turboget
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   # Debug build
   flutter run
   
   # Release build
   flutter run --release
   ```

### Building

```bash
# Android APK
flutter build apk --debug
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS (Simulator)
flutter build ios --simulator --no-codesign

# Web
flutter build web --release
```

---

## Project Structure

### Directory Overview

```
lib/
├── main.dart                 # Entry point with error handling
├── providers/                # Riverpod state providers
│   ├── auth_provider.dart
│   ├── download_provider.dart
│   ├── settings_provider.dart
│   └── theme_provider.dart
├── models/                   # Data models
│   ├── download_item.dart
│   ├── user.dart
│   └── ...
├── screens/                  # App screens
│   ├── home_screen.dart
│   ├── login_screen.dart
│   ├── settings_screen.dart
│   └── ...
├── services/                 # Business services
│   ├── auth_service.dart
│   ├── download_service.dart
│   ├── database_service.dart
│   ├── logger_service.dart
│   └── validation_service.dart
└── widgets/                  # Reusable widgets
    └── ...
```

### Key Services

| Service | Purpose |
|---------|---------|
| `AuthService` | User authentication and management |
| `DownloadService` | Download queue and execution |
| `DatabaseService` | SQLite persistence layer |
| `LoggerService` | Structured logging with multiple outputs |
| `ValidationService` | Input sanitization and validation |
| `ExceptionHandler` | Global error handling |

---

## Configuration

### Environment Variables

Configure the app using Dart defines:

```bash
# Admin credentials
--dart-define=ADMIN_USERNAME=admin
--dart-define=ADMIN_PASSWORD=your_secure_password

# Environment
--dart-define=ENVIRONMENT=production
```

### Android Configuration

The `android/app/build.gradle` contains:
- Min SDK: 21
- Target SDK: 34
- MultiDex enabled for large apps

### AdMob Setup

Replace test ad unit IDs in `lib/services/ad_manager.dart` with your production IDs:

```dart
static String get bannerAdUnitId => 'ca-app-pub-YOUR-ID-HERE/XXXXXXXXXX';
```

---

## Testing

### Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/services/auth_service_test.dart

# Run with verbose output
flutter test --reporter expanded
```

### Test Structure

```
test/
├── services/
│   ├── auth_service_test.dart
│   └── validation_service_test.dart
├── models/
│   └── download_item_test.dart
└── widget_test.dart
```

### Coverage Reports

Generate HTML coverage report:

```bash
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Code Standards

- Follow Flutter/Dart style guidelines
- Add tests for new features
- Update documentation as needed
- Run `flutter analyze` before committing

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add new download algorithm
fix: resolve download pause issue
docs: update README
test: add validation tests
refactor: improve error handling
```

---

## Security

### Reporting Vulnerabilities

If you discover a security vulnerability, please report it privately to the maintainers.

### Security Best Practices

- Admin credentials are configurable via environment variables
- All user input is validated and sanitized
- Passwords are generated using cryptographically secure random
- Sensitive data is not logged
- URLs are sanitized before logging

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- [Flutter](https://flutter.dev) - UI framework
- [Riverpod](https://riverpod.dev) - State management
- [Google Mobile Ads](https://developers.google.com/admob/flutter/quick-start) - Monetization
- [flutter_downloader](https://pub.dev/packages/flutter_downloader) - Background downloads

---

<div align="center">

**Built with ❤️ by the TurboGet Team**

</div>
