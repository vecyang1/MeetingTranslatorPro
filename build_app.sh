#!/bin/bash
# Build script for Meeting Translator macOS app
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Meeting Translator"
BUNDLE_NAME="MeetingTranslator"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
INSTALL_DIR="/Applications"
INSTALL_APP="$INSTALL_DIR/$BUNDLE_NAME.app"

echo "=== Building Meeting Translator ==="
echo "Project: $PROJECT_DIR"

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p /tmp/mtp-swift-module-cache

# Get SDK path
SDK=$(xcrun --sdk macosx --show-sdk-path)
echo "SDK: $SDK"

# Compile
echo "Compiling Swift sources..."
swiftc \
  -module-cache-path /tmp/mtp-swift-module-cache \
  -sdk "$SDK" \
  -target arm64-apple-macosx14.0 \
  -parse-as-library \
  -suppress-warnings \
  -O \
  -framework SwiftUI \
  -framework AppKit \
  -framework AVFoundation \
  -framework ScreenCaptureKit \
  -framework CoreAudio \
  -framework AudioToolbox \
  -framework CoreMedia \
  -framework Combine \
  -framework UniformTypeIdentifiers \
  -o "$BUILD_DIR/$BUNDLE_NAME" \
  Sources/MeetingTranslator/Models/TranscriptionEntry.swift \
  Sources/MeetingTranslator/Models/AppSettings.swift \
  Sources/MeetingTranslator/Services/WhisperService.swift \
  Sources/MeetingTranslator/Services/TranslationService.swift \
  Sources/MeetingTranslator/Services/GeminiFlashService.swift \
  Sources/MeetingTranslator/Services/GeminiLiveService.swift \
  Sources/MeetingTranslator/Services/CostTracker.swift \
  Sources/MeetingTranslator/Services/AudioOutputRouteInspector.swift \
  Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift \
  Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift \
  Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModelRouter.swift \
  Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeEventReducer.swift \
  Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeDraftFinalizer.swift \
  Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeUtteranceMerger.swift \
  Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeConnectionRecoveryPolicy.swift \
  Sources/MeetingTranslator/Services/OpenAIRealtime/AudioResampler.swift \
  Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeTranslatedAudioPlayer.swift \
  Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeWebSocketService.swift \
  Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeTranscriptionService.swift \
  Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeTranslationService.swift \
  Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeAgentService.swift \
  Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeCoordinator.swift \
  Sources/MeetingTranslator/Managers/MicrophoneManager.swift \
  Sources/MeetingTranslator/Managers/SystemAudioManager.swift \
  Sources/MeetingTranslator/Managers/AppState.swift \
  Sources/MeetingTranslator/Views/VisualEffectBackground.swift \
  Sources/MeetingTranslator/Views/AudioLevelIndicator.swift \
  Sources/MeetingTranslator/Views/TranscriptionRowView.swift \
  Sources/MeetingTranslator/Views/SettingsView.swift \
  Sources/MeetingTranslator/Views/ContentView.swift \
  Sources/MeetingTranslator/MeetingTranslatorApp.swift

echo "Compilation successful!"

# Create .app bundle structure
echo "Creating app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$BUNDLE_NAME" "$APP_BUNDLE/Contents/MacOS/$BUNDLE_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Create app icon from Resources/AppIcon.png (1024x1024 source icon)
echo "Creating app icon..."
ICON_PNG="$PROJECT_DIR/Resources/AppIcon.png"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

if [ -f "$ICON_PNG" ]; then
    sips -z 16 16 "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16.png" 2>/dev/null
    sips -z 32 32 "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" 2>/dev/null
    sips -z 32 32 "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32.png" 2>/dev/null
    sips -z 64 64 "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" 2>/dev/null
    sips -z 128 128 "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128.png" 2>/dev/null
    sips -z 256 256 "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" 2>/dev/null
    sips -z 256 256 "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256.png" 2>/dev/null
    sips -z 512 512 "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" 2>/dev/null
    sips -z 512 512 "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512.png" 2>/dev/null
    sips -z 1024 1024 "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" 2>/dev/null

    iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null || echo "iconutil not available, using PNG icon"
    echo "App icon created from Resources/AppIcon.png"
else
    echo "WARNING: Resources/AppIcon.png not found — app will have no icon"
fi

# Sign the app with a stable certificate so macOS doesn't reset permissions on each rebuild.
# Prefer Apple Development certificate if available, otherwise fall back to ad-hoc.
echo "Signing app..."

# Look for Apple Development certificate first (most stable, preserves TCC permissions)
APPLE_DEV_CERT=$(security find-identity -v -p codesigning 2>/dev/null | grep 'Apple Development' | head -1 | awk -F'"' '{print $2}')

if [ -n "$APPLE_DEV_CERT" ]; then
    echo "Using Apple Development certificate: $APPLE_DEV_CERT"
    codesign --force --deep --sign "$APPLE_DEV_CERT" \
        --entitlements "$PROJECT_DIR/Resources/MeetingTranslator.entitlements" \
        "$APP_BUNDLE" 2>/dev/null || echo "Codesign completed with notes"
    echo "Signed with Apple Development certificate — permissions will persist across rebuilds."
else
    # Fall back to ad-hoc signing
    echo "No Apple Development certificate found. Using ad-hoc signing."
    echo "NOTE: Screen Recording permission will need to be re-granted after each rebuild."
    codesign --force --deep --sign - \
        --entitlements "$PROJECT_DIR/Resources/MeetingTranslator.entitlements" \
        "$APP_BUNDLE" 2>/dev/null || echo "Codesign completed with notes"
fi

# Install to /Applications
echo ""
echo "Installing to $INSTALL_APP ..."
rm -rf "$INSTALL_APP"
cp -R "$APP_BUNDLE" "$INSTALL_APP"
echo "Installed to $INSTALL_APP"

echo ""
echo "=== Build Complete ==="
echo "App bundle: $APP_BUNDLE"
echo "Installed:  $INSTALL_APP"
echo ""
echo "To run: open \"$INSTALL_APP\""
echo ""
echo "IMPORTANT: On first launch, macOS will ask for:"
echo "  1. Microphone permission — for capturing your voice"
echo "  2. Screen Recording permission — for capturing system/meeting audio"
echo "  Grant both for full functionality."
