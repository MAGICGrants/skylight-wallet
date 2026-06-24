import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

const _libName = 'openalias_ffi';

DynamicLibrary _load() {
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  } else if (Platform.isIOS || Platform.isMacOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  } else if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('${Platform.operatingSystem} is not supported');
}

typedef _ResolveNative = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Uint16);
typedef _ResolveDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, int);
typedef _FreeNative = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);
typedef _LastErrorNative = Pointer<Utf8> Function();
typedef _LastErrorDart = Pointer<Utf8> Function();

class OpenAliasException implements Exception {
  OpenAliasException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Resolves OpenAlias domains to addresses with end-to-end DNSSEC validation,
/// over Tor. Backed by a Rust (hickory) native library.
class OpenAliasFfi {
  /// Resolves [domain]'s `oa1:<asset>` record to a recipient address, routing
  /// DNS through the Tor SOCKS proxy at [socksPort] and requiring the answer to
  /// be DNSSEC-secure. Returns null if no matching record; throws
  /// [OpenAliasException] on failure (no DNSSEC, network, parse, ...).
  ///
  /// Runs in a background isolate (the native call blocks while it queries Tor).
  static Future<String?> resolve({
    required String domain,
    required String asset,
    required int socksPort,
  }) {
    return Isolate.run(() => _resolveSync(domain, asset, socksPort));
  }
}

String? _resolveSync(String domain, String asset, int socksPort) {
  final lib = _load();
  final resolve = lib.lookupFunction<_ResolveNative, _ResolveDart>('openalias_resolve');
  final freeStr = lib.lookupFunction<_FreeNative, _FreeDart>('openalias_string_free');
  final lastError = lib.lookupFunction<_LastErrorNative, _LastErrorDart>(
    'openalias_last_error_message',
  );

  final domainPtr = domain.toNativeUtf8();
  final assetPtr = asset.toNativeUtf8();
  try {
    final result = resolve(domainPtr, assetPtr, socksPort);
    if (result == nullptr) {
      final errPtr = lastError();
      final message = errPtr == nullptr || errPtr.toDartString().isEmpty
          ? 'OpenAlias resolution failed'
          : errPtr.toDartString();
      if (errPtr != nullptr) freeStr(errPtr);
      throw OpenAliasException(message);
    }
    final address = result.toDartString();
    freeStr(result);
    return address.isEmpty ? null : address;
  } finally {
    malloc.free(domainPtr);
    malloc.free(assetPtr);
  }
}
