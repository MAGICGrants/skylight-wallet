import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:spice_wallet/theme/brand.dart';
import 'package:spice_wallet/widgets/ui/coin_tile.dart';

/// A coin's icon: the chain-coloured tile with its white glyph for the known
/// chains, falling back to the coin's own logo asset for anything else.
class CoinMark extends StatelessWidget {
  final String coinSymbol;
  final String iconAsset;
  final double size;

  /// Connection-status dot on the bottom-right corner; null shows no dot.
  final Color? statusColor;

  /// Ring around the status dot, separating it from the icon — set to the colour
  /// behind the icon (defaults to the card fill).
  final Color? statusRingColor;

  /// Status-dot diameter as a fraction of [size]. Larger for small header icons
  /// where a proportional dot would be too tiny to read.
  final double statusDotFactor;

  const CoinMark({
    super.key,
    required this.coinSymbol,
    required this.iconAsset,
    this.size = 40,
    this.statusColor,
    this.statusRingColor,
    this.statusDotFactor = 0.32,
  });

  static ({Color color, String glyph})? _mark(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'XMR':
        return (color: BrandColors.monero, glyph: 'assets/icons/monero-glyph.svg');
      case 'BTC':
        return (color: BrandColors.bitcoin, glyph: 'assets/icons/bitcoin-glyph.svg');
      case 'TBTC':
        // Testnet Bitcoin — green to distinguish it from mainnet at a glance.
        return (color: const Color(0xFF3E9B6E), glyph: 'assets/icons/bitcoin-glyph.svg');
      case 'ETH':
        return (color: BrandColors.ethereum, glyph: 'assets/icons/ethereum-glyph.svg');
      case 'SETH':
        // Sepolia testnet — grey to distinguish it from mainnet Ethereum.
        return (color: const Color(0xFF8A8F98), glyph: 'assets/icons/ethereum-glyph.svg');
      case 'DAI':
        return (color: BrandColors.dai, glyph: 'assets/icons/dai-glyph.svg');
      case 'SDAI':
        // Sepolia testnet token — grey, matching Sepolia Ethereum.
        return (color: const Color(0xFF8A8F98), glyph: 'assets/icons/dai-glyph.svg');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final mark = _mark(coinSymbol);
    final Widget icon = mark == null
        ? SvgPicture.asset(iconAsset, width: size, height: size)
        : CoinTile(
            size: size,
            color: mark.color,
            glyph: SvgPicture.asset(mark.glyph, width: size * 0.63, height: size * 0.63),
          );

    if (statusColor == null) return icon;

    final dot = size * statusDotFactor;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: statusRingColor ?? BrandColors.card, width: dot * 0.17),
            ),
          ),
        ),
      ],
    );
  }
}
