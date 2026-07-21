#!/bin/bash
# Debian Package Build Script for Spice Wallet
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

# Version for package metadata (without 'v' prefix)
PKG_VERSION="${VERSION#v}"
# Version for output filename (with 'v' prefix)
FILE_VERSION="v${PKG_VERSION}"

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
rm -rf spice-wallet-* || true
PACKAGE_DIR="spice-wallet-${FILE_VERSION}-amd64"
mkdir -p "$PACKAGE_DIR/DEBIAN"
mkdir -p "$PACKAGE_DIR/usr/lib/spice-wallet"
mkdir -p "$PACKAGE_DIR/usr/bin"
mkdir -p "$PACKAGE_DIR/usr/share/icons/hicolor/512x512/apps"
mkdir -p "$PACKAGE_DIR/usr/share/applications"

# Create control file
echo "Creating control file..."
INSTALLED_SIZE=$(du -sk ../build/linux/x64/release/bundle | cut -f1)
cat > "$PACKAGE_DIR/DEBIAN/control" << EOF
Package: spice-wallet
Version: $PKG_VERSION
Section: finance
Priority: optional
Architecture: amd64
Installed-Size: $INSTALLED_SIZE
Maintainer: MAGIC Grants
Description: A light Monero wallet.
Homepage: https://github.com/spice-wallet/spice-wallet
EOF

# Copy the Flutter bundle to lib directory
echo "Copying Flutter bundle..."
cp -r ../build/linux/x64/release/bundle/* "$PACKAGE_DIR/usr/lib/spice-wallet/"

# Create wrapper script in /usr/bin
echo "Creating launcher script..."
cat > "$PACKAGE_DIR/usr/bin/spice-wallet" << 'EOF'
#!/bin/bash
INSTALL_DIR="/usr/lib/spice-wallet"
export LD_LIBRARY_PATH="$INSTALL_DIR/lib:$LD_LIBRARY_PATH"
exec "$INSTALL_DIR/spice_wallet" "$@"
EOF
chmod 755 "$PACKAGE_DIR/usr/bin/spice-wallet"

# Copy icon
echo "Copying icon..."
cp ../linux/launcher_icon.png "$PACKAGE_DIR/usr/share/icons/hicolor/512x512/apps/spice-wallet.png"

# Create desktop file
echo "Creating desktop entry..."
cat > "$PACKAGE_DIR/usr/share/applications/spice-wallet.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Spice Wallet
Comment=Monero cryptocurrency wallet
Exec=spice-wallet
Icon=spice-wallet
Categories=Finance;Network;
Terminal=false
EOF

# Set proper permissions
echo "Setting permissions..."
find "$PACKAGE_DIR" -type d -exec chmod 755 {} \;
find "$PACKAGE_DIR/usr/lib/spice-wallet" -type f -name "*.so*" -exec chmod 644 {} \;
chmod 755 "$PACKAGE_DIR/usr/lib/spice-wallet/spice_wallet"
chmod 644 "$PACKAGE_DIR/usr/share/applications/spice-wallet.desktop"
chmod 644 "$PACKAGE_DIR/usr/share/icons/hicolor/512x512/apps/spice-wallet.png"
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
echo "Remove with:  sudo dpkg -r spice-wallet"
