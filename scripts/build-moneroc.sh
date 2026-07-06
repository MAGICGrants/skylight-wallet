#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive DEBCONF_NOWARNINGS=yes
apt update
apt install -y apt-utils
apt install -y build-essential pkg-config autoconf libtool ccache make cmake gcc g++ git curl \
  lbzip2 libtinfo5 gperf unzip python-is-python3 llvm gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64

update-alternatives --set x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix
update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix

git config --global --add safe.directory '*'
git config --global user.email "info@magicgrants.org"
git config --global user.name "MAGIC Grants"

REPO="$PWD"

# Reproducible builds: build at a FIXED canonical path so the depends prefix baked
# into openssl/unbound match.
# Symlink it back into the workspace so this workflow's later `cp monero_c/...` steps resolve.
# Single source of truth: the monero_c commit pinned in pubspec.lock.
MONEROC_COMMIT=$(awk '/^  monero:/{f=1} f&&/resolved-ref:/{gsub(/"/,"",$2);print $2;exit}' "$REPO/pubspec.lock")
[ -n "$MONEROC_COMMIT" ] || { echo "could not read monero resolved-ref from pubspec.lock"; exit 1; }

rm -rf /tmp/monero_c "$REPO/monero_c"
git clone https://github.com/vtnerd/monero_c.git /tmp/monero_c
ln -s /tmp/monero_c "$REPO/monero_c"
cd /tmp/monero_c
git checkout "$MONEROC_COMMIT"
git submodule update --init

# Pin timestamps: apply_patches' `git am` commit SHA (baked into Monero's version
# string) and __DATE__/__TIME__ must be deterministic
export SOURCE_DATE_EPOCH="$(git log -1 --format=%ct)"
export GIT_COMMITTER_DATE="@$SOURCE_DATE_EPOCH"

./apply_patches.sh monero
patch -p1 < "$REPO/scripts/reproducible.patch"
./build_single.sh monero $TARGET_ARCH -j$(nproc)