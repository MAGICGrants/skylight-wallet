#!/bin/bash
# Debian Package Build Script for Skylight Wallet
#
# Usage: ./build_deb.sh --version <version>
#
# This script builds a .deb package from the Linux Flutter build.
#
# Requirements:
# - dpkg-deb (usually pre-installed on Debian/Ubuntu)
# - fakeroot (optional, for proper ownership without root)

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
            echo "  -v, --version    Version string for the package (required)"
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

# Strip 'v' prefix if present for package version
PKG_VERSION="${VERSION#v}"

echo "Building .deb package version: $PKG_VERSION"

# Get the project root directory (parent of deb folder)
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Check for dpkg-deb
if ! command -v dpkg-deb &> /dev/null; then
    echo "Error: dpkg-deb is required but not installed."
    echo "Install it with: sudo apt install dpkg"
    exit 1
fi

# Check if Flutter build exists
if [ ! -d "build/linux/x64/release/bundle" ]; then
    echo "Error: Flutter Linux build not found."
    echo "Run 'flutter build linux --release' first."
    exit 1
fi

echo "Creating Debian package structure..."
cd deb
rm -rf skylight-wallet_* || true
PACKAGE_DIR="skylight-wallet_${PKG_VERSION}_amd64"
mkdir -p "$PACKAGE_DIR/DEBIAN"
mkdir -p "$PACKAGE_DIR/usr/lib/skylight-wallet"
mkdir -p "$PACKAGE_DIR/usr/bin"
mkdir -p "$PACKAGE_DIR/usr/share/icons/hicolor/512x512/apps"
mkdir -p "$PACKAGE_DIR/usr/share/applications"

# Create control file
echo "Creating control file..."
INSTALLED_SIZE=$(du -sk ../build/linux/x64/release/bundle | cut -f1)
cat > "$PACKAGE_DIR/DEBIAN/control" << EOF
Package: skylight-wallet
Version: $PKG_VERSION
Section: finance
Priority: optional
Architecture: amd64
Installed-Size: $INSTALLED_SIZE
Maintainer: Skylight Wallet Developers
Description: Monero cryptocurrency wallet
 A light Monero wallet with privacy-focused features.
 Skylight Wallet provides an easy-to-use interface for
 managing Monero cryptocurrency.
Homepage: https://github.com/skylight-wallet/skylight-wallet
EOF

# Copy the Flutter bundle to lib directory
echo "Copying Flutter bundle..."
cp -r ../build/linux/x64/release/bundle/* "$PACKAGE_DIR/usr/lib/skylight-wallet/"

# Create wrapper script in /usr/bin
echo "Creating launcher script..."
cat > "$PACKAGE_DIR/usr/bin/skylight-wallet" << 'EOF'
#!/bin/bash
INSTALL_DIR="/usr/lib/skylight-wallet"
export LD_LIBRARY_PATH="$INSTALL_DIR/lib:$LD_LIBRARY_PATH"
exec "$INSTALL_DIR/skylight_wallet" "$@"
EOF
chmod 755 "$PACKAGE_DIR/usr/bin/skylight-wallet"

# Copy icon
echo "Copying icon..."
cp ../linux/launcher_icon.png "$PACKAGE_DIR/usr/share/icons/hicolor/512x512/apps/skylight-wallet.png"

# Create desktop file
echo "Creating desktop entry..."
cat > "$PACKAGE_DIR/usr/share/applications/skylight-wallet.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Skylight Wallet
Comment=Monero cryptocurrency wallet
Exec=skylight-wallet
Icon=skylight-wallet
Categories=Finance;Network;
Terminal=false
EOF

# Set proper permissions
echo "Setting permissions..."
find "$PACKAGE_DIR" -type d -exec chmod 755 {} \;
find "$PACKAGE_DIR/usr/lib/skylight-wallet" -type f -name "*.so*" -exec chmod 644 {} \;
chmod 755 "$PACKAGE_DIR/usr/lib/skylight-wallet/skylight_wallet"
chmod 644 "$PACKAGE_DIR/usr/share/applications/skylight-wallet.desktop"
chmod 644 "$PACKAGE_DIR/usr/share/icons/hicolor/512x512/apps/skylight-wallet.png"
chmod 644 "$PACKAGE_DIR/DEBIAN/control"

# Build the .deb package
echo "Building .deb package..."
if command -v fakeroot &> /dev/null; then
    fakeroot dpkg-deb --build "$PACKAGE_DIR"
else
    echo "Note: fakeroot not found, using dpkg-deb directly"
    echo "      Install fakeroot for proper file ownership in package"
    dpkg-deb --build "$PACKAGE_DIR"
fi

DEB_FILE="${PACKAGE_DIR}.deb"

# Verify the package
echo "Verifying package..."
dpkg-deb --info "$DEB_FILE"

# Clean up build directory
echo "Cleaning up..."
rm -rf "$PACKAGE_DIR"

echo ""
echo "✓ Debian package created successfully!"
echo "Output: deb/$DEB_FILE"
echo ""
echo "Install with: sudo dpkg -i deb/$DEB_FILE"
echo "Remove with:  sudo dpkg -r skylight-wallet"
