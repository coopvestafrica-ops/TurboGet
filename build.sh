#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
# TurboGet Build Script
# Build standalone desktop and mobile apps
# Designed by Olatunji Ayobami Ayanlowo +2347038193753
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           🚀 TurboGet Build Script v1.0              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}Error: Flutter not found!${NC}"
    echo "Please install Flutter SDK from: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Flutter version
echo -e "${GREEN}Using Flutter:${NC}"
flutter --version
echo ""

# Parse arguments
PLATFORM=${1:-all}
BUILD_TYPE=${2:-release}

# Function to build for platform
build_platform() {
    local platform=$1
    local desc=$2
    
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Building for $desc...${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    
    case $platform in
        windows)
            flutter build windows --$BUILD_TYPE
            echo -e "${GREEN}✓ Windows build complete!${NC}"
            echo "Output: build/windows/runner/Release/TurboGet.exe"
            ;;
        macos)
            flutter build macos --$BUILD_TYPE
            echo -e "${GREEN}✓ macOS build complete!${NC}"
            echo "Output: build/macos/Build/Products/Release/TurboGet.app"
            ;;
        linux)
            flutter build linux --$BUILD_TYPE
            echo -e "${GREEN}✓ Linux build complete!${NC}"
            echo "Output: build/linux/x64/release/bundle/TurboGet"
            ;;
        web)
            flutter build web --$BUILD_TYPE
            echo -e "${GREEN}✓ Web build complete!${NC}"
            echo "Output: build/web/"
            ;;
        android)
            flutter build apk --$BUILD_TYPE
            echo -e "${GREEN}✓ Android APK build complete!${NC}"
            echo "Output: build/app/outputs/flutter-apk/app-release.apk"
            ;;
        ios)
            flutter build ios --$BUILD_TYPE --no-codesign
            echo -e "${GREEN}✓ iOS build complete!${NC}"
            echo "Output: build/ios/iphoneos/Runner.app"
            ;;
        all)
            echo -e "${YELLOW}Building all platforms...${NC}"
            flutter build web --$BUILD_TYPE
            flutter build apk --$BUILD_TYPE
            flutter build windows --$BUILD_TYPE
            flutter build macos --$BUILD_TYPE
            flutter build linux --$BUILD_TYPE
            echo -e "${GREEN}✓ All builds complete!${NC}"
            ;;
        *)
            echo -e "${RED}Unknown platform: $platform${NC}"
            echo "Usage: ./build.sh [windows|macos|linux|web|android|ios|all]"
            exit 1
            ;;
    esac
}

# Desktop dependencies setup
setup_desktop() {
    echo -e "${YELLOW}Setting up desktop dependencies...${NC}"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Installing Linux desktop dependencies..."
        sudo apt-get update
        sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "For macOS, ensure Xcode Command Line Tools are installed..."
        xcode-select --install
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        echo "For Windows, ensure Visual Studio Build Tools are installed..."
    fi
    
    echo -e "${GREEN}Desktop dependencies ready!${NC}"
}

# Main
case $PLATFORM in
    setup)
        setup_desktop
        ;;
    help|--help|-h)
        echo "Usage: ./build.sh [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  windows    Build Windows executable"
        echo "  macos      Build macOS app"
        echo "  linux      Build Linux app"
        echo "  web        Build web app"
        echo "  android    Build Android APK"
        echo "  ios        Build iOS app"
        echo "  all        Build all platforms"
        echo "  setup      Install desktop dependencies"
        echo "  help       Show this help message"
        echo ""
        echo "Examples:"
        echo "  ./build.sh web              # Build web app"
        echo "  ./build.sh windows          # Build Windows .exe"
        echo "  ./build.sh android debug    # Build debug APK"
        echo "  ./build.sh all              # Build everything"
        ;;
    *)
        build_platform $PLATFORM "$PLATFORM"
        ;;
esac

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              🎉 Build Process Complete!                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Designed by Olatunji Ayobami Ayanlowo +2347038193753"
