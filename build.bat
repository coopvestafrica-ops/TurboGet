@echo off
REM ═══════════════════════════════════════════════════════════════════════════════
REM TurboGet Build Script for Windows
REM Build standalone desktop and mobile apps
REM Designed by Olatunji Ayobami Ayanlowo +2347038193753
REM ═══════════════════════════════════════════════════════════════════════════════

color 0B
echo.
echo ╔══════════════════════════════════════════════════════════╗
echo ║           TurboGet Build Script v1.0                   ║
echo ╚══════════════════════════════════════════════════════════╝
echo.

REM Check Flutter
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Flutter not found!
    echo Please install Flutter SDK from: https://flutter.dev/docs/get-started/install
    pause
    exit /b 1
)

REM Flutter version
echo [INFO] Using Flutter:
flutter --version
echo.

REM Parse arguments
set PLATFORM=%1
if "%PLATFORM%"=="" set PLATFORM=all
set BUILD_TYPE=%2
if "%BUILD_TYPE%"=="" set BUILD_TYPE=release

REM Build for platform
if "%PLATFORM%"=="windows" (
    echo ═════════════════════════════════════════════════════════════
    echo Building for Windows...
    echo ═════════════════════════════════════════════════════════════
    flutter build windows --%BUILD_TYPE%
    if %errorlevel%==0 (
        echo.
        echo [SUCCESS] Windows build complete!
        echo Output: build\windows\runner\Release\TurboGet.exe
    )
) else if "%PLATFORM%"=="macos" (
    echo ═════════════════════════════════════════════════════════════
    echo Building for macOS...
    echo ═════════════════════════════════════════════════════════════
    flutter build macos --%BUILD_TYPE%
    if %errorlevel%==0 (
        echo.
        echo [SUCCESS] macOS build complete!
        echo Output: build\macos\Build\Products\Release\TurboGet.app
    )
) else if "%PLATFORM%"=="linux" (
    echo ═════════════════════════════════════════════════════════════
    echo Building for Linux...
    echo ═════════════════════════════════════════════════════════════
    flutter build linux --%BUILD_TYPE%
    if %errorlevel%==0 (
        echo.
        echo [SUCCESS] Linux build complete!
        echo Output: build\linux\x64\release\bundle\TurboGet
    )
) else if "%PLATFORM%"=="web" (
    echo ═════════════════════════════════════════════════════════════
    echo Building for Web...
    echo ═════════════════════════════════════════════════════════════
    flutter build web --%BUILD_TYPE%
    if %errorlevel%==0 (
        echo.
        echo [SUCCESS] Web build complete!
        echo Output: build\web\
    )
) else if "%PLATFORM%"=="android" (
    echo ═════════════════════════════════════════════════════════════
    echo Building for Android...
    echo ═════════════════════════════════════════════════════════════
    flutter build apk --%BUILD_TYPE%
    if %errorlevel%==0 (
        echo.
        echo [SUCCESS] Android APK build complete!
        echo Output: build\app\outputs\flutter-apk\app-release.apk
    )
) else if "%PLATFORM%"=="ios" (
    echo ═════════════════════════════════════════════════════════════
    echo Building for iOS...
    echo ═════════════════════════════════════════════════════════════
    flutter build ios --%BUILD_TYPE% --no-codesign
    if %errorlevel%==0 (
        echo.
        echo [SUCCESS] iOS build complete!
        echo Output: build\ios\iphoneos\Runner.app
    )
) else if "%PLATFORM%"=="all" (
    echo [INFO] Building all platforms...
    call :build_all
) else if "%PLATFORM%"=="setup" (
    echo [INFO] Setting up Windows desktop dependencies...
    echo Please ensure Visual Studio Build Tools are installed with:
    echo   - "Desktop development with C++"
    echo   - "Windows 10/11 SDK
) else (
    echo [USAGE] build.bat [windows^|macos^|linux^|web^|android^|ios^|all]
    echo.
    echo Examples:
    echo   build.bat web              - Build web app
    echo   build.bat windows          - Build Windows .exe
    echo   build.bat android debug    - Build debug APK
    echo   build.bat all              - Build everything
    echo   build.bat setup            - Show setup instructions
    pause
    exit /b 1
)

echo.
echo ╔══════════════════════════════════════════════════════════╗
echo ║              Build Process Complete!                    ║
echo ╚══════════════════════════════════════════════════════════╝
echo.
echo Designed by Olatunji Ayobami Ayanlowo +2347038193753
echo.
pause
exit /b 0

:build_all
    flutter build web --%BUILD_TYPE%
    flutter build apk --%BUILD_TYPE%
    flutter build windows --%BUILD_TYPE%
    REM Uncomment for macOS/Linux if on those platforms:
    REM flutter build macos --%BUILD_TYPE%
    REM flutter build linux --%BUILD_TYPE%
    echo [SUCCESS] All builds complete!
    exit /b 0
