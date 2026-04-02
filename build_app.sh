#!/bin/bash
# Build script for Meeting Translator macOS app
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Meeting Translator"
BUNDLE_NAME="MeetingTranslator"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "=== Building Meeting Translator ==="
echo "Project: $PROJECT_DIR"

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Get SDK path
SDK=$(xcrun --sdk macosx --show-sdk-path)
echo "SDK: $SDK"

# Compile
echo "Compiling Swift sources..."
swiftc \
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

# Generate app icon using Python (creates a simple gradient icon)
python3 << 'PYTHON_SCRIPT'
import struct
import zlib
import os

def create_png(width, height, pixels):
    """Create a minimal PNG file from pixel data."""
    def chunk(chunk_type, data):
        c = chunk_type + data
        crc = struct.pack('>I', zlib.crc32(c) & 0xffffffff)
        return struct.pack('>I', len(data)) + c + crc

    header = b'\x89PNG\r\n\x1a\n'
    ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))

    raw = b''
    for y in range(height):
        raw += b'\x00'  # filter none
        for x in range(width):
            raw += bytes(pixels[y * width + x])

    idat = chunk(b'IDAT', zlib.compress(raw))
    iend = chunk(b'IEND', b'')

    return header + ihdr + idat + iend

size = 512
pixels = []
for y in range(size):
    for x in range(size):
        # Gradient from blue to purple
        t = (x + y) / (2 * size)
        r = int(60 + t * 120)
        g = int(80 + (1-t) * 60)
        b = int(200 + t * 55)

        # Circle mask with anti-aliasing
        cx, cy = size/2, size/2
        radius = size * 0.45
        dist = ((x - cx)**2 + (y - cy)**2)**0.5

        if dist < radius - 2:
            alpha = 255
        elif dist < radius + 2:
            alpha = int(255 * max(0, (radius + 2 - dist) / 4))
        else:
            alpha = 0

        # Add waveform-like pattern in center
        center_y = size / 2
        wave_height = size * 0.15
        wave_x = (x - size * 0.25) / (size * 0.5)
        if 0 <= wave_x <= 1 and alpha > 0:
            import math
            wave = math.sin(wave_x * math.pi * 4) * wave_height * (1 - abs(wave_x - 0.5) * 2)
            if abs(y - center_y - wave) < size * 0.02:
                r, g, b = 255, 255, 255

        pixels.append((r, g, b, alpha))

png_data = create_png(size, size, pixels)

build_dir = os.environ.get('BUILD_DIR', 'build')
icon_path = os.path.join(build_dir, 'icon.png')
with open(icon_path, 'wb') as f:
    f.write(png_data)
print(f"Icon created: {icon_path}")
PYTHON_SCRIPT

# Create .icns from PNG
echo "Creating app icon..."
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

# Use sips to resize the icon for all required sizes
ICON_PNG="$BUILD_DIR/icon.png"
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
    cp "$ICON_PNG" "$ICONSET_DIR/icon_512x512@2x.png"

    iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null || echo "iconutil not available, using PNG icon"
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

echo ""
echo "=== Build Complete ==="
echo "App bundle: $APP_BUNDLE"
echo ""
echo "To run: open \"$APP_BUNDLE\""
echo ""
echo "IMPORTANT: On first launch, macOS will ask for:"
echo "  1. Microphone permission — for capturing your voice"
echo "  2. Screen Recording permission — for capturing system/meeting audio"
echo "  Grant both for full functionality."
