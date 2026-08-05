import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'src/openalias_records.dart';

export 'src/openalias_records.dart';

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

typedef _SecureTxtNative = Pointer<Utf8> Function(Pointer<Utf8>, Uint16);
typedef _SecureTxtDart = Pointer<Utf8> Function(Pointer<Utf8>, int);
typedef _FreeNative = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);
typedef _LastErrorNative = Pointer<Utf8> Function();
typedef _LastErrorDart = Pointer<Utf8> Function();

/// Resolves OpenAlias aliases to addresses with end-to-end DNSSEC validation,
/// over Tor. Backed by a Rust (hickory) native library.
class OpenAliasFfi {
  /// Resolves [alias] — an FQDN or an email-style `name@domain` — to a payment
  /// record, requiring a DNSSEC-secure answer and routing every query through
  /// the Tor SOCKS proxy at [socksPort].
  ///
  /// OpenAlias v2 is preferred and v1 is the fallback, as the spec's
  /// compatibility rule requires: when the recipient publishes any usable
  /// `_openalias-payment` record, only those are considered, and the `oa1:`
  /// record on the FQDN is used only when they publish none.
  ///
  /// [network] and [asset] say what the caller can pay (`xmr` and `xmr` for
  /// Monero). [nativeAsset] is that network's native asset per the OA2 network
  /// list, which is what a v2 record that omits `asset` denotes. [asset] also
  /// selects the v1 prefix to look for (`oa1:xmr`).
  ///
  /// Throws [NotAnAliasException] if [alias] is a raw address rather than an
  /// alias, and [OpenAliasException] on anything else that leaves us without an
  /// address: no record, an answer that is not DNSSEC-secure, a network
  /// failure, or a recipient who publishes v2 records but none this wallet can
  /// pay.
  ///
  /// The native calls block while they query Tor, so each one runs in a
  /// background isolate.
  static Future<OpenAliasResult> resolve({
    required String alias,
    required String network,
    required String asset,
    required int socksPort,
    String? nativeAsset,
    bool fetchMetadata = true,
  }) async {
    final fqdn = normalizeAlias(alias);

    // The three names are independent, and each lookup is a slow round trip
    // over Tor, so they run concurrently rather than one after another;
    // resolveFromLookups then decides which answer gets used. Metadata is
    // fetched for its display name only, and never blocks a payment.
    final lookups = await Future.wait([
      _lookup('$oa2PaymentPrefix.$fqdn', socksPort),
      fetchMetadata
          ? _lookup('$oa2MetadataPrefix.$fqdn', socksPort)
          : Future.value(const _TxtLookup.skipped()),
      _lookup(fqdn, socksPort),
    ]);
    final oa2Payment = lookups[0];
    final oa2Metadata = lookups[1];
    final oa1 = lookups[2];

    return resolveFromLookups(
      OpenAliasLookups(
        paymentRecords: oa2Payment.records,
        metadataRecords: oa2Metadata.records,
        oa1Records: oa1.records,
        paymentProblem: oa2Payment.problem,
        oa1Problem: oa1.problem,
      ),
      alias: alias,
      network: network,
      asset: asset,
      nativeAsset: nativeAsset,
    );
  }
}

/// One name's TXT records, or why there are none. A failed lookup is not fatal
/// on its own — the caller decides, since v1 can still answer when v2 does not
/// (and the reason is kept for the error message if nothing answers).
class _TxtLookup {
  const _TxtLookup(this.records) : problem = null;
  const _TxtLookup.failed(this.problem) : records = const [];
  const _TxtLookup.skipped() : records = const [], problem = 'not looked up';

  final List<String> records;
  final String? problem;
}

Future<_TxtLookup> _lookup(String name, int socksPort) async {
  try {
    return _TxtLookup(await Isolate.run(() => _secureTxtSync(name, socksPort)));
  } on OpenAliasException catch (e) {
    return _TxtLookup.failed(e.message);
  } catch (e) {
    return _TxtLookup.failed(e.toString());
  }
}

/// Fetches the DNSSEC-validated TXT records at [name] through the native
/// resolver. Each record comes back with its DNS character-strings already
/// concatenated. Throws [OpenAliasException] when the answer could not be
/// validated, the name has no TXT records, or the lookup failed.
List<String> _secureTxtSync(String name, int socksPort) {
  final lib = _load();
  final secureTxt = lib.lookupFunction<_SecureTxtNative, _SecureTxtDart>('openalias_secure_txt');
  final freeStr = lib.lookupFunction<_FreeNative, _FreeDart>('openalias_string_free');
  final lastError = lib.lookupFunction<_LastErrorNative, _LastErrorDart>(
    'openalias_last_error_message',
  );

  final namePtr = name.toNativeUtf8();
  try {
    final result = secureTxt(namePtr, socksPort);
    if (result == nullptr) {
      final errPtr = lastError();
      final message = errPtr == nullptr || errPtr.toDartString().isEmpty
          ? 'OpenAlias lookup failed'
          : errPtr.toDartString();
      if (errPtr != nullptr) freeStr(errPtr);
      throw OpenAliasException(message);
    }

    final String encoded;
    try {
      encoded = result.toDartString();
    } finally {
      // The buffer was allocated by Rust; hand it back even if decoding throws.
      freeStr(result);
    }

    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw OpenAliasException('resolver returned malformed output for $name');
    }
    return [for (final record in decoded) record as String];
  } finally {
    malloc.free(namePtr);
  }
}
