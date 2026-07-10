import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _androidOptions = AndroidOptions(encryptedSharedPreferences: true);
const _appleOptions = IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device);
const _macOptions = MacOsOptions(accessibility: KeychainAccessibility.first_unlock_this_device);

const secureStorage = FlutterSecureStorage(
  aOptions: _androidOptions,
  iOptions: _appleOptions,
  mOptions: _macOptions,
);
