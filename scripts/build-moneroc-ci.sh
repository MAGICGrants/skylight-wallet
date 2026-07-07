#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive DEBCONF_NOWARNINGS=yes
apt update
apt install -y apt-utils
apt install -y build-essential pkg-config autoconf libtool ccache make cmake gcc g++ git curl \
  lbzip2 gperf unzip python-is-python3 llvm gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64
apt install -y libtinfo5 2>/dev/null || echo "libtinfo5 unavailable (trixie) — skipping"

update-alternatives --set x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix
update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix

git config --global --add safe.directory '*'
git config --global user.email "info@magicgrants.org"
git config --global user.name "MAGIC Grants"

REPO="$PWD"
# Shared reproducible monero_c build — identical code path to the F-Droid recipe, so the
# committed .so matches F-Droid's rebuild. Clones from the remote (this CI checkout has no
# populated submodule); then symlink output where build-monero-c.yml's cp step expects it.
rm -rf "$REPO/monero_c"
bash scripts/build-moneroc.sh "$TARGET_ARCH" https://github.com/vtnerd/monero_c.git
ln -s /tmp/monero_c "$REPO/monero_c"