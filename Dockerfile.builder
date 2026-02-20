# Using Debian Bullseye for maximum AppImage compatibility (GLIBC 2.31)
FROM debian:bullseye-20251117@sha256:ee239c601913c0d3962208299eef70dcffcb7aac1787f7a02f6d3e2b518755e6

ARG FLUTTER_VERSION

ARG RUST_VERSION=1.83.0
ARG ANDROID_CMDLINE_TOOLS_VERSION=11076708
ARG ANDROID_BUILD_TOOLS_VERSION=36.0.0
ARG ANDROID_PLATFORM_VERSION=36
ARG ANDROID_NDK_VERSION=28.0.13004108

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
    libstdc++-10-dev \
    openjdk-17-jdk-headless \
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

# Install Rust with pinned version
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain ${RUST_VERSION} --profile minimal && \
    . ${CARGO_HOME}/env && \
    rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android

# Install Android SDK command-line tools with pinned version
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    cd ${ANDROID_HOME}/cmdline-tools && \
    curl -o cmdtools.zip https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip && \
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
