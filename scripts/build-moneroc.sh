#!/bin/bash
set -e

apt update
apt upgrade -y
apt install -y build-essential pkg-config autoconf libtool ccache make cmake gcc g++ git curl \
  lbzip2 libtinfo5 gperf unzip python-is-python3 llvm gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64

update-alternatives --set x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix
update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix

git config --global --add safe.directory '*'
git config --global user.email "info@magicgrants.org"
git config --global user.name "MAGIC Grants"

git clone https://github.com/vtnerd/monero_c.git
cd monero_c
git checkout lwsf
git submodule update --init
./apply_patches.sh monero
./build_single.sh monero $TARGET_ARCH -j$(nproc)