# Skylight Wallet

A modern, open-source, and self-custody Monero light-wallet built with Flutter.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.8.1+-02569B.svg?logo=flutter)

## Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** (3.8.1 or higher) - [Installation guide](https://docs.flutter.dev/get-started/install)
- **Dart SDK** (3.8.1 or higher) - Usually comes with Flutter
- **Android Studio** - For Android development
- **Android SDK** - API level 21+ (Android 5.0 Lollipop or higher)
- **Java JDK** - Version 11 or higher

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/magicgrants/skylight-wallet.git
cd skylight-wallet
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Android Development Environment

1. **Install Android Studio** and the Android SDK
2. **Accept Android licenses**:
   ```bash
   flutter doctor --android-licenses
   ```
3. **Set up a device**:
   - Use an Android emulator (AVD Manager in Android Studio), or
   - Connect a physical Android device with USB debugging enabled
4. **Verify setup**:
   ```bash
   flutter doctor
   ```
   This will check for any missing dependencies

## Development

### Running the App

#### Debug Mode (Development)

Run the app in debug mode with hot reload:

```bash
# Run on connected device or emulator
flutter run

# List available Android devices/emulators
flutter devices

# Run on a specific device
flutter run -d <device_id>
```

Make sure you have an Android emulator running or a physical device connected before running the app.

## Building for Android

### Debug APK

Build a debug APK for testing:

```bash
flutter build apk --debug
```

The APK will be located at: `build/app/outputs/flutter-apk/app-debug.apk`

### Release APK

Build a debug APK for release:

```bash
flutter build apk --release
```

The APK will be located at: `build/app/outputs/flutter-apk/app-release.apk`

#### Split APKs by ABI (smaller file sizes)

```bash
flutter build apk --split-per-abi --release
```

This creates separate APKs for each architecture:
- `app-armeabi-v7a-release.apk` (32-bit ARM)
- `app-arm64-v8a-release.apk` (64-bit ARM)
- `app-x86_64-release.apk` (64-bit x86)

### Installing the APK

To install the built APK on your device:

```bash
# Install debug APK
flutter install

# Or manually using adb
adb install build/app/outputs/flutter-apk/app-release.apk
```

**Note**: Other platforms (iOS, Linux, macOS, Windows, Web) are not currently supported but may be added in future releases.

## Localization

The app uses Flutter's internationalization framework. To add a new language:

1. Create a new ARB file in `lib/l10n/` (e.g., `app_es.arb` for Spanish)
2. Copy the structure from `app_en.arb` and translate the strings
3. Run code generation:
   ```bash
   flutter gen-l10n
   ```
4. The generated localization files will be in `lib/l10n/`

## Building `libmonero_libwallet2_api_c.so`

This is needed for the wallet functions and is located at `android/app/src/main/jniLibs/<platform>/`.

These instructions should work on Ubuntu 22.04. You can use the `ubuntu:22.04` Docker image if you don't use Ubuntu as your OS.

### Install dependencies

```bash
$ apt update
$ apt install -y build-essential pkg-config autoconf libtool \
    ccache make cmake gcc g++ git curl lbzip2 libtinfo5 gperf \
    unzip python-is-python3 llvm
```

### Prepare source

```bash
$ git clone https://github.com/vtnerd/monero_c --recursive
$ cd monero_c
$ git checkout lwsf
$ git submodule update --init
$ ./apply_patches.sh monero
```

### Building

```bash
# For armeabi-v7a
$ ./build_single.sh monero armv7a-linux-androideabi -j$(nproc)

# For arm64-v8a
$ ./build_single.sh monero aarch64-linux-android -j$(nproc)

# For x86_64
$ ./build_single.sh monero x86_64-linux-android -j$(nproc)
```

## Contributing

Pull requests welcome! Thanks for supporting MAGIC Grants.

## License

[MIT](LICENSE)