FROM debian:trixie@sha256:6788062a1b42ac281f053ac876170b79a3eaed5d61383b8ed7eaca6c6965f3b1

ARG FLUTTER_VERSION

# Passed by build-builder-image.yml from rust-toolchain.toml (single source of truth).
ARG RUST_VERSION
# Installer/SDK tool pins (version + checksum). Bump version and hash together.
ARG RUSTUP_VERSION=1.28.2
ARG RUSTUP_INIT_SHA256=20a06e644b0d9bd2fbdbfd52d42540bdde820ea7df86e92e533c073da0cdd43c
ARG ANDROID_CMDLINE_TOOLS_VERSION=11076708
ARG ANDROID_CMDLINE_TOOLS_SHA256=2d2d50857e4eb553af5a6dc3ad507a17adf43d115264b1afc116f95c92e5e258
ARG ANDROID_BUILD_TOOLS_VERSION=36.0.0
ARG ANDROID_PLATFORM_VERSION=36
ARG ANDROID_NDK_VERSION=28.1.13356709

# Install system dependencies with pinned versions
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    liblzma-dev \
    libstdc++-14-dev \
    openjdk-21-jdk-headless \
    ca-certificates \
    build-essential \
    make \
    perl \
    libssl-dev \
    libsecret-1-dev \
    libsecret-1-0 \
    file \
    fakeroot && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /usr/share/man/*

ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV CARGO_HOME=/opt/cargo
ENV RUSTUP_HOME=/opt/rustup
ENV PATH="/flutter/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${CARGO_HOME}/bin:${PATH}"
ENV FLUTTER_ROOT="/flutter"

# Install Rust via a pinned, checksum-verified rustup-init (not curl|sh of a
# live installer script). The toolchain itself is pinned by RUST_VERSION and
# verified by rustup on download.
RUN curl --proto '=https' --tlsv1.2 -sSfL -o /tmp/rustup-init \
      "https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/x86_64-unknown-linux-gnu/rustup-init" && \
    echo "${RUSTUP_INIT_SHA256}  /tmp/rustup-init" | sha256sum -c - && \
    chmod +x /tmp/rustup-init && \
    /tmp/rustup-init -y --default-toolchain ${RUST_VERSION} --profile minimal && \
    rm /tmp/rustup-init && \
    . ${CARGO_HOME}/env && \
    rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android

# Install Android SDK command-line tools with pinned version + checksum
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    cd ${ANDROID_HOME}/cmdline-tools && \
    curl -fsSL -o cmdtools.zip https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip && \
    echo "${ANDROID_CMDLINE_TOOLS_SHA256}  cmdtools.zip" | sha256sum -c - && \
    unzip cmdtools.zip && \
    mv cmdline-tools latest && \
    rm cmdtools.zip

# Install Android SDK components with pinned versions
RUN yes | sdkmanager --licenses && \
    sdkmanager --install \
    "platform-tools" \
    "platforms;android-${ANDROID_PLATFORM_VERSION}" \
    "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" \
    "ndk;${ANDROID_NDK_VERSION}" && \
    rm -rf ${ANDROID_HOME}/.android/cache && \
    rm -rf ${ANDROID_HOME}/ndk/*/sources/third_party/shaderc && \
    rm -rf ${ANDROID_HOME}/ndk/*/sources/cxx-stl/llvm-libc++/test && \
    rm -rf ${ANDROID_HOME}/ndk/*/shader-tools && \
    rm -rf ${ANDROID_HOME}/ndk/*/simpleperf

# Install Flutter with pinned version
RUN git clone https://github.com/flutter/flutter.git -b ${FLUTTER_VERSION} --depth 1 /flutter && \
    git config --system --add safe.directory /flutter && \
    flutter doctor -v && \
    flutter config --enable-linux-desktop && \
    flutter config --no-analytics && \
    flutter precache --linux --android && \
    find /flutter -name "*.zip" -delete && \
    rm -rf /flutter/examples /flutter/dev/devicelab /flutter/dev/benchmarks && \
    rm -rf /flutter/.pub-cache/hosted/pub.dev/*/example

WORKDIR /workspace
