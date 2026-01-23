#!/bin/bash
# AppImage Build Script for Skylight Wallet
#
# Usage: ./build_appimage.sh --version <version>
#
# This script builds a Linux AppImage with integrity verification.
# 
# To update the expected SHA256 hash:
# 1. Visit: https://github.com/probonopd/go-appimage/releases
# 2. Download appimagetool-x86_64.AppImage
# 3. Run: sha256sum appimagetool-x86_64.AppImage
# 4. Update EXPECTED_SHA256 variable below
#
# Or verify manually before first run:
# wget https://github.com/probonopd/go-appimage/releases/download/continuous/appimagetool-x86_64.AppImage
# sha256sum appimagetool-x86_64.AppImage
# # Compare with hash from trusted source

set -e

# Parse command line arguments
VERSION=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 --version <version>"
            echo ""
            echo "Arguments:"
            echo "  -v, --version    Version string for the AppImage (required)"
            echo "  -h, --help       Show this help message"
            echo ""
            echo "Example:"
            echo "  $0 --version 1.0.0"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if version is provided
if [ -z "$VERSION" ]; then
    echo "Error: --version is required"
    echo "Usage: $0 --version <version>"
    echo "Example: $0 --version 1.0.0"
    exit 1
fi

# Version without 'v' prefix (for internal use)
VERSION="${VERSION#v}"
# Version for output filename (with 'v' prefix)
FILE_VERSION="v${VERSION}"

echo "Building AppImage version: $FILE_VERSION"

# Get the project root directory (parent of appimage folder)
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Check if Flutter build exists
if [ ! -d "build/linux/x64/release/bundle" ]; then
    echo "Error: Flutter Linux build not found."
    echo "Run 'flutter build linux --release' first."
    exit 1
fi

echo "Creating AppImage structure..."
cd appimage
rm -rf AppDir || true
mkdir -p AppDir/usr/bin
mkdir -p AppDir/usr/lib
mkdir -p AppDir/usr/share/icons/hicolor/512x512/apps
mkdir -p AppDir/usr/share/applications

# Copy the Flutter bundle
echo "Copying Flutter bundle..."
cp -r ../build/linux/x64/release/bundle/* AppDir/usr/bin/

# Copy icon
echo "Copying icon..."
cp ../linux/launcher_icon.png AppDir/usr/share/icons/hicolor/512x512/apps/skylight_wallet.png
cp ../linux/launcher_icon.png AppDir/skylight_wallet.png

# Copy desktop file
echo "Creating desktop entry..."
cp skylight_wallet.desktop AppDir/usr/share/applications/
cp skylight_wallet.desktop AppDir/

# Create AppRun
echo "Creating AppRun..."
cat > AppDir/AppRun << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin/:${HERE}/usr/sbin/:${HERE}/usr/games/:${HERE}/bin/:${HERE}/sbin/${PATH:+:$PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib/:${HERE}/usr/lib/i386-linux-gnu/:${HERE}/usr/lib/x86_64-linux-gnu/:${HERE}/usr/lib32/:${HERE}/usr/lib64/${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="${HERE}/usr/share/${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
EXEC="${HERE}/usr/bin/skylight_wallet"
exec "${EXEC}" "$@"
EOF

chmod +x AppDir/AppRun

# Expected SHA256 hash - update this when updating appimagetool
# Verify from: https://github.com/probonopd/go-appimage/releases
# Run: sha256sum appimagetool-x86_64.AppImage
EXPECTED_SHA256="f9cd2ea644b4a6a8fdd6966642511f0f3c76aa4a81f58c07f102f369d50a5292"
APPIMAGETOOL_FILENAME="appimagetool-940-x86_64.AppImage"

# Download appimagetool from go-appimage if not present
if [ ! -f "$APPIMAGETOOL_FILENAME" ]; then
    echo "Downloading appimagetool (go-appimage)..."
    wget -q --show-progress "https://github.com/probonopd/go-appimage/releases/download/continuous/$APPIMAGETOOL_FILENAME"
    chmod +x $APPIMAGETOOL_FILENAME
fi

# Verify integrity
echo "Verifying appimagetool integrity..."
ACTUAL_SHA256=$(sha256sum $APPIMAGETOOL_FILENAME | awk '{print $1}')

if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
    echo "⚠ ERROR: SHA256 hash mismatch!"
    echo "Expected: $EXPECTED_SHA256"
    echo "Got:      $ACTUAL_SHA256"
    echo ""
    echo "Either the file is corrupted/tampered, or a new version was released."
    echo "Verify the hash manually and update EXPECTED_SHA256 in the script if needed."
    exit 1
fi

echo "✓ Integrity verified"

# Extract appimagetool if not already extracted (avoids FUSE requirement)
if [ ! -d "squashfs-root" ]; then
    echo "Extracting appimagetool..."
    ./$APPIMAGETOOL_FILENAME --appimage-extract > /dev/null
fi

# Build the AppImage
echo "Packaging AppImage..."
export VERSION
export ARCH=x86_64
./squashfs-root/AppRun AppDir

GENERATED_APPIMAGE=$(ls -1 Skylight_Wallet-${VERSION}-*.AppImage 2>/dev/null | head -n1)
DESIRED_NAME="skylight-wallet-${FILE_VERSION}-x86_64.AppImage"

if [ -n "$GENERATED_APPIMAGE" ]; then
    echo "Renaming to: $DESIRED_NAME"
    mv "$GENERATED_APPIMAGE" "$DESIRED_NAME"
    chmod +x "$DESIRED_NAME"
fi

# Clean up temporary files
echo "Cleaning up..."
rm -rf AppDir squashfs-root

echo ""
echo "✓ AppImage created successfully!"
if [ -f "$DESIRED_NAME" ]; then
    echo "Output: $DESIRED_NAME"
    echo "Run with: ./appimage/$DESIRED_NAME"
else
    echo "Error: AppImage file not found!"
    exit 1
fi
