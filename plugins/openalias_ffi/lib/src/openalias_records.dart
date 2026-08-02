/// Pure-Dart OpenAlias record handling: alias normalization, OpenAlias v1 and
/// v2 record parsing, and v2 record selection.
///
/// Deliberately free of `dart:ffi` so the grammar can be unit-tested without a
/// native build (see `test/openalias_records_test.dart`). The DNSSEC-validated
/// lookup that feeds it lives in `openalias_ffi.dart`.
library;

/// OA2 records live under these prefixes on the alias FQDN, while OA1 records
/// live on the FQDN itself — which is how both can coexist for one recipient.
const String oa2PaymentPrefix = '_openalias-payment';
const String oa2MetadataPrefix = '_openalias-metadata';

/// A record with no `priority` is the lowest priority there is.
const int _noPriority = 1 << 30;

class OpenAliasException implements Exception {
  OpenAliasException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The input is a raw address rather than an alias, so nothing was looked up.
class NotAnAliasException extends OpenAliasException {
  NotAnAliasException(super.message);
}

/// A payment destination parsed from an OpenAlias record.
class OpenAliasPayment {
  const OpenAliasPayment({
    required this.version,
    required this.network,
    required this.address,
    this.asset,
    this.addressType,
    this.priority,
    this.amount,
    this.memo,
    this.recipientName,
    this.description,
    this.fields = const {},
  });

  /// 1 for an `oa1:` record, 2 for an `_openalias-payment` record.
  final int version;

  /// OA2 `network`. OA1 has no network field, so its asset prefix stands in
  /// (`oa1:xmr` → `xmr`), which is what that prefix means in practice.
  final String network;

  final String address;

  /// OA2 `asset`; null when the record omits it, which denotes the network's
  /// native asset.
  final String? asset;

  /// OA2 `address_type`, e.g. `bip352`. Informational.
  final String? addressType;

  /// OA2 `priority`; lower is preferred. Null when the record omits it.
  final int? priority;

  /// A requested amount in the asset's standard units, as published. A request
  /// to prefill, never a constraint on what the sender sends.
  final String? amount;

  /// A network-specific identifier (destination tag, Stellar memo, legacy
  /// Monero payment ID). OA1 publishes this as `tx_payment_id`.
  final String? memo;

  /// OA1 `recipient_name`. OA2 publishes the name in its metadata record
  /// instead, so this is null for v2 records.
  final String? recipientName;

  /// OA1 `tx_description`.
  final String? description;

  /// Every parsed pair, including keys this client does not recognize.
  final Map<String, String> fields;

  /// The asset this record pays. An omitted `asset` denotes [nativeAsset] — the
  /// network's native asset per the OA2 network list — which is why the caller
  /// has to supply it: on some networks the native asset is not the network
  /// code (the native asset on `base` is `eth`).
  String? effectiveAsset(String? nativeAsset) => asset ?? nativeAsset;
}

/// A resolved alias: the record to pay, plus what else the recipient published
/// for the user to check before sending.
class OpenAliasResult {
  const OpenAliasResult({required this.payment, this.alternatives = const [], this.metadata});

  /// The record this wallet should pay.
  final OpenAliasPayment payment;

  /// The other records this wallet could have paid, next-preferred first.
  final List<OpenAliasPayment> alternatives;

  /// The recipient's `_openalias-metadata` record, when they publish one (v2
  /// only).
  final Map<String, String>? metadata;

  /// 1 if this came from an `oa1:` record, 2 from `_openalias-payment`.
  int get version => payment.version;

  /// A display name for the recipient: the v2 metadata `name`, or the v1
  /// `recipient_name`. Recipient-supplied text, for display only — it never
  /// affects which address is paid.
  String? get recipientName => metadata?['name'] ?? payment.recipientName;
}

/// The raw TXT records found at an alias's three names, plus why a lookup came
/// back empty. Separating this from the lookups themselves keeps the choice
/// below testable without DNS.
class OpenAliasLookups {
  const OpenAliasLookups({
    this.paymentRecords = const [],
    this.metadataRecords = const [],
    this.oa1Records = const [],
    this.paymentProblem,
    this.oa1Problem,
  });

  /// TXT records at `_openalias-payment.<fqdn>`.
  final List<String> paymentRecords;

  /// TXT records at `_openalias-metadata.<fqdn>`.
  final List<String> metadataRecords;

  /// TXT records at the alias FQDN itself, where OA1 records live.
  final List<String> oa1Records;

  /// Why the v2 payment lookup returned nothing, if it failed.
  final String? paymentProblem;

  /// Why the v1 lookup returned nothing, if it failed.
  final String? oa1Problem;
}

/// Decides what to pay from already-fetched records.
///
/// OpenAlias v2 is preferred and v1 is the fallback, as the spec's
/// compatibility rule requires: when the recipient publishes any usable
/// `_openalias-payment` record, only those are considered, and the `oa1:`
/// record on the FQDN is used only when they publish none.
///
/// [network], [asset] and [nativeAsset] describe what the caller can pay; see
/// [selectPayments]. [alias] is used only in error messages. Throws
/// [OpenAliasException] when nothing payable was published.
OpenAliasResult resolveFromLookups(
  OpenAliasLookups lookups, {
  required String alias,
  required String network,
  required String asset,
  String? nativeAsset,
}) {
  // A record that fails to parse is skipped rather than fatal: only records
  // that are actually usable v2 payments count as "the recipient publishes v2",
  // so one malformed record can't strand a working v1 alias.
  final v2 = <OpenAliasPayment>[];
  for (final text in lookups.paymentRecords) {
    final fields = parseKeyValueRecord(text);
    if (fields == null) continue;
    final record = parseOa2Payment(fields);
    if (record != null) v2.add(record);
  }

  if (v2.isNotEmpty) {
    final payable = selectPayments(v2, network: network, asset: asset, nativeAsset: nativeAsset);
    if (payable.isEmpty) {
      // Falling back to v1 here would pay an address the recipient has since
      // superseded, so this fails instead. Record content is publisher-chosen
      // and this message is logged, so only a bounded summary of it is quoted.
      final offered = v2.map((record) => _clip(record.network)).toSet().take(4).join(', ');
      throw OpenAliasException(
        '$alias publishes ${v2.length} OpenAlias v2 payment record(s) '
        '($offered) but none for $asset on $network',
      );
    }
    return OpenAliasResult(
      payment: payable.first,
      alternatives: payable.skip(1).toList(),
      metadata: parseMetadata(lookups.metadataRecords),
    );
  }

  for (final text in lookups.oa1Records) {
    final record = parseOa1Payment(text, asset);
    if (record != null) return OpenAliasResult(payment: record);
  }

  throw OpenAliasException(
    'no OpenAlias record for $asset at $alias '
    '(v2: ${lookups.paymentProblem ?? 'no usable payment record'}; '
    'v1: ${lookups.oa1Problem ?? 'no oa1:$asset record'})',
  );
}

/// Normalizes user input into the alias FQDN to query (OA2 "Resolving
/// OpenAlias Records", step 1).
///
/// `donate@openalias.org` becomes `donate.openalias.org`, and a trailing root
/// dot is dropped. Throws [NotAnAliasException] when the input contains no `.`
/// — per the spec that is a raw address, not an alias — and
/// [OpenAliasException] when it is malformed. Internationalized names are
/// passed through as typed: the native resolver converts non-ASCII labels to
/// their A-label (Punycode) form when it parses the name.
String normalizeAlias(String input) {
  var alias = input.trim();
  while (alias.endsWith('.')) {
    alias = alias.substring(0, alias.length - 1);
  }
  if (alias.isEmpty) {
    throw NotAnAliasException('empty input');
  }

  final ats = '@'.allMatches(alias).length;
  if (ats > 1) {
    throw OpenAliasException("malformed alias '$input': more than one '@'");
  }
  if (ats == 1) {
    alias = alias.replaceFirst('@', '.');
  }
  if (!alias.contains('.')) {
    throw NotAnAliasException("'$input' looks like a raw address, not an alias");
  }

  final labels = alias.split('.');
  if (labels.any((label) => label.isEmpty)) {
    throw OpenAliasException("malformed alias '$input': contains an empty label");
  }
  if (alias.length > 253 || labels.any((label) => label.length > 63)) {
    throw OpenAliasException("malformed alias '$input': name is too long for DNS");
  }

  // DNS names are case-insensitive; lower-casing keeps the caller's resolve
  // cache from missing on the same alias typed differently.
  return alias.toLowerCase();
}

/// Parses one TXT record into `{key: value}` pairs per the OA2 Key-Value
/// Encoding rules.
///
/// Returns null when the record is not key-value data at all, uses a key
/// outside the allowed characters, or repeats a key — the spec requires
/// rejecting a repeated key rather than guessing which value was meant.
Map<String, String>? parseKeyValueRecord(String text) {
  final fields = <String, String>{};

  // Pairs are separated by ';', with an optional space after it and an optional
  // trailing ';'. A value may itself contain '=' (only the first is
  // significant) but never ';'.
  for (final pair in text.split(';')) {
    final trimmed = pair.trim();
    if (trimmed.isEmpty) continue;

    final eq = trimmed.indexOf('=');
    if (eq < 0) return null;

    final key = trimmed.substring(0, eq).trim().toLowerCase();
    final value = trimmed.substring(eq + 1).trim();
    if (!_keyPattern.hasMatch(key)) return null;
    if (fields.containsKey(key)) return null;

    fields[key] = value;
  }

  return fields;
}

/// Keys are ASCII letters, digits and underscores, matched case-insensitively.
final RegExp _keyPattern = RegExp(r'^[a-z0-9_]+$');

/// Builds a payment record from the fields of an `_openalias-payment` record,
/// or null when it is not a usable v2 payment: a version other than 2, or a
/// missing required field, must be rejected rather than interpreted.
///
/// Unrecognized keys are kept in [OpenAliasPayment.fields] and otherwise
/// ignored, so records can gain keys without breaking this client.
OpenAliasPayment? parseOa2Payment(Map<String, String> fields) {
  if (fields['oa_version'] != '2') return null;

  final network = _nonEmpty(fields['network']);
  final address = _nonEmpty(fields['address']);
  if (network == null || address == null) return null;

  final priority = fields['priority'];

  return OpenAliasPayment(
    version: 2,
    network: network,
    address: address,
    asset: _nonEmpty(fields['asset']),
    addressType: _nonEmpty(fields['address_type']),
    priority: priority == null ? null : int.tryParse(priority),
    amount: _nonEmpty(fields['amount']),
    memo: _nonEmpty(fields['memo']),
    fields: Map.unmodifiable(fields),
  );
}

/// Parses an OA1 record (`oa1:<asset> recipient_address=...;`) for [asset].
/// Returns null when the record is for a different asset, is not an OA1 record,
/// or has no recipient address.
OpenAliasPayment? parseOa1Payment(String text, String asset) {
  final prefix = 'oa1:${asset.toLowerCase()}';
  final trimmed = text.trimLeft();
  if (!trimmed.toLowerCase().startsWith(prefix)) return null;

  // The prefix is its own token: `oa1:xmrfoo` is not an `oa1:xmr` record.
  final rest = trimmed.substring(prefix.length);
  if (rest.isNotEmpty && !rest.startsWith(' ')) return null;

  final fields = parseKeyValueRecord(rest);
  if (fields == null) return null;

  final address = _nonEmpty(fields['recipient_address']);
  if (address == null) return null;

  return OpenAliasPayment(
    version: 1,
    network: asset.toLowerCase(),
    asset: asset.toLowerCase(),
    address: address,
    amount: _nonEmpty(fields['tx_amount']),
    memo: _nonEmpty(fields['tx_payment_id']),
    recipientName: _nonEmpty(fields['recipient_name']),
    description: _nonEmpty(fields['tx_description']),
    fields: Map.unmodifiable(fields),
  );
}

/// The subset of [records] this wallet can pay, most-preferred first.
///
/// Filters to [network] and [asset] — where a record that omits `asset` denotes
/// [nativeAsset] — and then orders by `priority`, lower first, with records
/// that publish no priority last (OA2 "Choosing Priorities": prefer the
/// recipient's stated priority among the records the sender supports).
List<OpenAliasPayment> selectPayments(
  List<OpenAliasPayment> records, {
  required String network,
  required String asset,
  String? nativeAsset,
}) {
  final payable = <OpenAliasPayment>[];
  for (final record in records) {
    if (!_sameToken(record.network, network)) continue;
    final effective = record.effectiveAsset(nativeAsset);
    if (effective != null && _sameToken(effective, asset)) payable.add(record);
  }

  // Sorted on (priority, published order): List.sort is not stable, and records
  // sharing a priority should stay in the order the zone published them.
  final ordered = payable.asMap().entries.toList();
  ordered.sort((a, b) {
    final byPriority = (a.value.priority ?? _noPriority).compareTo(b.value.priority ?? _noPriority);
    return byPriority != 0 ? byPriority : a.key.compareTo(b.key);
  });

  return [for (final entry in ordered) entry.value];
}

/// The first `_openalias-metadata` record among [texts], or null. Metadata is
/// optional and must never block a payment.
Map<String, String>? parseMetadata(List<String> texts) {
  for (final text in texts) {
    final fields = parseKeyValueRecord(text);
    if (fields != null && fields['oa_version'] == '2') return fields;
  }
  return null;
}

bool _sameToken(String a, String b) => a.toLowerCase() == b.toLowerCase();

/// Bounds a publisher-supplied value quoted in an error message.
String _clip(String value) => value.length <= 16 ? value : '${value.substring(0, 16)}…';

String? _nonEmpty(String? value) => (value == null || value.isEmpty) ? null : value;
