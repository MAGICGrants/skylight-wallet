// Neutral wallet display types, shared across screens and the wallet engine.
// These used to live in wallet_model.dart; they moved here when the legacy
// WalletModel engine was removed and the app went wallet-core-only.

/// A validated OpenAlias resolution: the Monero address to pay, plus what the
/// recipient published about themselves, for the confirm screen.
class ResolvedOpenAlias {
  ResolvedOpenAlias({required this.address, required this.version, this.recipientName});

  final String address;

  /// 1 if this came from an `oa1:xmr` record, 2 from `_openalias-payment`.
  final int version;

  /// The recipient's display name, if they published one. Display only — it has
  /// no bearing on [address].
  final String? recipientName;
}

class TxDetails {
  final int? index;
  final int direction;
  final String hash;
  final double amount;
  final double fee;
  final List<TxRecipient> recipients;
  final int? accountIndex;
  final List<int> subaddrIndexList;
  final int timestamp;
  final int height;
  final int confirmations;
  final String key;

  TxDetails({
    required this.index,
    required this.direction,
    required this.hash,
    required this.amount,
    required this.fee,
    required this.recipients,
    required this.accountIndex,
    required this.subaddrIndexList,
    required this.timestamp,
    required this.height,
    required this.confirmations,
    required this.key,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'direction': direction,
    'hash': hash,
    'amount': amount,
    'fee': fee,
    'recipients': recipients.map((r) => r.toJson()).toList(),
    'accountIndex': accountIndex,
    'subaddrIndexList': subaddrIndexList,
    'timestamp': timestamp,
    'height': height,
    'confirmations': confirmations,
    'key': key,
  };

  factory TxDetails.fromJson(Map<String, dynamic> json) => TxDetails(
    index: json['index'] as int?,
    direction: json['direction'] as int,
    hash: json['hash'] as String,
    amount: (json['amount'] as num).toDouble(),
    fee: (json['fee'] as num).toDouble(),
    recipients: (json['recipients'] as List<dynamic>)
        .map((r) => TxRecipient.fromJson(r as Map<String, dynamic>))
        .toList(),
    accountIndex: json['accountIndex'] as int?,
    subaddrIndexList: (json['subaddrIndexList'] as List<dynamic>).cast<int>(),
    timestamp: json['timestamp'] as int,
    height: json['height'] as int,
    confirmations: json['confirmations'] as int,
    key: json['key'] as String,
  );
}

class TxRecipient {
  final String address;
  final double amount;

  TxRecipient(this.address, this.amount);

  Map<String, dynamic> toJson() => {'address': address, 'amount': amount};

  factory TxRecipient.fromJson(Map<String, dynamic> json) =>
      TxRecipient(json['address'] as String, (json['amount'] as num).toDouble());
}

class LWSConnectionDetails {
  final String address;
  final String proxyPort;
  final bool useTor;
  final bool useSsl;
  final String connectionType;

  LWSConnectionDetails({
    required this.address,
    required this.proxyPort,
    required this.useTor,
    required this.useSsl,
    this.connectionType = 'lws',
  });
}
