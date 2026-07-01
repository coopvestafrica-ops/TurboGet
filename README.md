# 🚀 TurboGet - Enterprise Download Manager

![TurboGet](https://img.shields.io/badge/Version-1.0.0-blue) ![Flutter](https://img.shields.io/badge/Flutter-3.44.4-blue) ![Platform](https://img.shields.io/badge/Platform-Web%20%7C%20Desktop%20%7C%20Mobile-green)

> **TurboGet** - The fastest download manager built with Flutter. Experience lightning-fast downloads with multi-connection technology, cloud sync, and enterprise-grade features.

**Designed by Olatunji Ayobami Ayanlowo**  
📞 +2347038193753

---

## ✨ Features

### ⚡ Turbo Download Engine
- **Multi-Connection Downloads** - Up to 16 parallel connections per file
- **Dynamic Segment Sizing** - Automatically optimized based on file size
- **Smart Retry** - Exponential backoff with jitter (up to 10 retries)
- **WiFi-Aware** - Pause on mobile, resume on WiFi
- **Bandwidth Control** - Set download speed limits
- **Queue Priority** - Urgent → High → Normal → Low

### 🎨 Beautiful UI
- **Animated Splash Screen** - Particle effects and elastic animations
- **Onboarding Flow** - 4 stunning introduction pages
- **Dark/Light Themes** - Professional gradient design system
- **Glassmorphism Cards** - Modern glass effects
- **Real-time Speed Meter** - Live download statistics

### ☁️ Enterprise Features
- **Cloud Sync** - Sync downloads across all devices
- **Scheduled Downloads** - One-time, daily, weekly, monthly
- **Media Preview** - Built-in player for videos and audio
- **Batch Downloads** - Import multiple URLs at once

---

## 📦 Supported Platforms

| Platform | Status | Build Command |
|----------|--------|---------------|
| 🖥️ Web | ✅ Ready | `flutter build web` |
| 🪟 Windows | ✅ Ready | `flutter build windows` |
| 🍎 macOS | ✅ Ready | `flutter build macos` |
| 🐧 Linux | ✅ Ready | `flutter build linux` |
| 📱 Android | ✅ Ready | `flutter build apk` |
| 📱 iOS | ✅ Ready | `flutter build ios` |

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.44.4 or higher
- Dart 3.12.5 or higher

### Installation

```bash
# Clone the repository
git clone https://github.com/coopvestafrica-ops/TurboGet.git
cd TurboGet

# Install dependencies (Web/Mobile)
flutter pub get

# For Desktop, use desktop dependencies
cp pubspec_desktop.yaml pubspec.yaml
flutter pub get

# Run the app (Web)
flutter run -d chrome

# Run the app (Desktop)
flutter run -d windows
flutter run -d macos
flutter run -d linux
```

---

## 🏗️ Building Standalone Apps

### Web
```bash
flutter build web --release
# Output: build/web/
```

### Windows
```bash
flutter build windows --release
# Output: build/windows/runner/Release/TurboGet.exe
```

### macOS
```bash
flutter build macos --release
# Output: build/macos/Build/Products/Release/TurboGet.app
```

### Linux
```bash
flutter build linux --release
# Output: build/linux/x64/release/bundle/TurboGet
```

### Android APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### iOS
```bash
flutter build ios --release --no-codesign
# Output: build/ios/iphoneos/Runner.app
```

---

## 🗂️ Project Structure

```
TurboGet/
├── lib/
│   ├── main.dart                    # Main entry (Mobile/Web)
│   ├── main_desktop.dart            # Desktop entry with window management
│   ├── screens/
│   │   ├── splash_screen.dart       # Animated splash
│   │   ├── onboarding_screen.dart   # 4-page onboarding
│   │   ├── turbo_dashboard_screen.dart  # Main dashboard
│   │   └── turbo_settings_screen.dart  # Settings UI
│   ├── services/
│   │   ├── turbo_downloader_engine.dart  # Core download engine
│   │   ├── cloud_sync_service.dart       # Cloud backup
│   │   ├── scheduled_downloads_service.dart  # Scheduling
│   │   └── app_theme.dart           # Design system
│   └── ...
├── pubspec.yaml                     # Mobile/Web dependencies
├── pubspec_desktop.yaml            # Desktop dependencies
└── README.md
```

---

## 🎨 Design System

**Designer:** Olatunji Ayobami Ayanlowo  
**Contact:** +2347038193753

### Brand Colors
| Color | Hex | Usage |
|-------|-----|-------|
| Primary Blue | `#0066FF` | Buttons, links |
| Primary Purple | `#8B5CF6` | Accents |
| Accent Cyan | `#00D9FF` | Highlights |
| Success Green | `#10B981` | Completed states |
| Error Red | `#EF4444` | Error states |

---

## 📊 Download Engine Performance

| File Size | Connections | Expected Speed |
|-----------|-------------|----------------|
| < 1 MB | 2 | Baseline |
| 1-10 MB | 4 | 2-4x faster |
| 10-50 MB | 6 | 4-6x faster |
| 50-200 MB | 8 | 6-8x faster |
| 200 MB - 1 GB | 12 | 8-10x faster |
| > 1 GB | 16 | Maximum speed |

---

## 🔧 Configuration

### Desktop App
```yaml
# pubspec_desktop.yaml
dependencies:
  window_manager: ^0.4.3
  system_tray: ^2.0.3
```

### Mobile App
```yaml
# pubspec.yaml
dependencies:
  google_mobile_ads: ^6.0.0
  flutter_downloader: ^1.11.0
```

---

## 📝 License

This project is proprietary software. All rights reserved.

**Owner:** Coopvest Africa  
**Designer:** Olatunji Ayobami Ayanlowo (+2347038193753)

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

---

## 📞 Support

- **Developer:** Olatunji Ayobami Ayanlowo
- **Phone:** +2347038193753
- **GitHub Issues:** [Open an Issue](https://github.com/coopvestafrica-ops/TurboGet/issues)

---

<p align="center">
  <strong>Built with ❤️ by Coopvest Africa</strong><br>
  <strong>Designed by Olatunji Ayobami Ayanlowo (+2347038193753)</strong>
</p>

