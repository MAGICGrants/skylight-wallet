import 'package:flutter/material.dart';

import 'package:spice_wallet/theme/brand.dart';
import 'package:spice_wallet/widgets/ui/coin_mark.dart';
import 'package:wallet_domain/wallet_domain.dart' show CryptoWallet;

/// Coin tile + name, used as a centred screen-header badge. Pass [label] to
/// override the coin name (e.g. "Monero Settings").
class CoinBadge extends StatelessWidget {
  final CryptoWallet? wallet;
  final String fallback;
  final String? label;
  final double size;

  /// Connection-status dot on the icon; null shows none.
  final Color? statusColor;

  /// Ring behind the status dot — set to the colour behind the header icon.
  final Color? statusRingColor;

  /// Status-dot diameter as a fraction of the icon size.
  final double statusDotFactor;

  const CoinBadge({
    super.key,
    required this.wallet,
    this.fallback = '',
    this.label,
    this.size = 22,
    this.statusColor,
    this.statusRingColor,
    this.statusDotFactor = 0.32,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (wallet != null)
          CoinMark(
            coinSymbol: wallet!.coinSymbol,
            iconAsset: wallet!.iconAsset,
            size: size,
            statusColor: statusColor,
            statusRingColor: statusRingColor,
            statusDotFactor: statusDotFactor,
          ),
        const SizedBox(width: 8),
        Text(
          label ?? wallet?.blockchainName ?? fallback,
          style: BrandText.appBar.copyWith(fontSize: 16),
        ),
      ],
    );
  }
}
