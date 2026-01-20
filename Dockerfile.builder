# Using Debian Bullseye for maximum AppImage compatibility (GLIBC 2.31)
FROM debian:bullseye-20251117@sha256:ee239c601913c0d3962208299eef70dcffcb7aac1787f7a02f6d3e2b518755e6
 
ARG TARGETARCH

ARG FLUTTER_VERSION=3.38.5
ARG RUST_VERSION=1.83.0
ARG ANDROID_CMDLINE_TOOLS_VERSION=11076708
ARG ANDROID_BUILD_TOOLS_VERSION=36.0.0
ARG ANDROID_PLATFORM_VERSION=36
ARG ANDROID_NDK_VERSION=28.0.13004108

# Install system dependencies with pinned versions
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl=7.74.0-1.3+deb11u16 \
    wget=1.21-1+deb11u2 \
    git=1:2.30.2-1+deb11u5 \
    unzip=6.0-26+deb11u1 \
    xz-utils=5.2.5-2.1~deb11u1 \
    zip=3.0-12 \
    libglu1-mesa=9.0.1-1 \
    clang=1:11.0-51+nmu5 \
    cmake=3.18.4-2+deb11u1 \
    ninja-build=1.10.1-1 \
    pkg-config=0.29.2-1 \
    libgtk-3-dev=3.24.24-4+deb11u4 \
    liblzma-dev=5.2.5-2.1~deb11u1 \
    libstdc++-10-dev=10.2.1-6 \
    openjdk-17-jdk=17.0.17+10-1~deb11u1 \
    ca-certificates=20210119 \
    build-essential=12.9 \
    make=4.3-4.1 \
    perl=5.32.1-4+deb11u4 \
    libssl-dev=1.1.1w-0+deb11u4 \
    libsecret-1-dev=0.20.4-2 \
    libsecret-1-0=0.20.4-2 \
    file=1:5.39-3+deb11u1 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-${TARGETARCH}
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
    rm -rf ${ANDROID_HOME}/.android/cache

# Install Flutter with pinned version
RUN git clone https://github.com/flutter/flutter.git -b ${FLUTTER_VERSION} --depth 1 /flutter && \
    flutter doctor -v && \
    flutter config --enable-linux-desktop && \
    flutter config --no-analytics && \
    flutter precache --linux --android && \
    find /flutter -name "*.zip" -delete

WORKDIR /workspace

