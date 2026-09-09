import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:spice_wallet/consts.dart' as consts;
import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/util/amount_units.dart';
import 'package:spice_wallet/util/format.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// A single transaction paired with the asset it belongs to, for a merged
/// activity timeline (coin home + global history).
typedef TxEntry = ({TxDetails tx, CryptoWallet asset});

/// One activity row: asset icon + direction badge, "Received/Sent" + time·chain,
/// and the signed amount with its fiat value.
class TxActivityRow extends StatelessWidget {
  final TxDetails tx;
  final CryptoWallet asset;
  final AppLocalizations i18n;
  final FiatRateModel fiatRate;
  final String fiatSymbol;
  final bool showDivider;
  final VoidCallback onTap;

  const TxActivityRow({
    super.key,
    required this.tx,
    required this.asset,
    required this.i18n,
    required this.fiatRate,
    required this.fiatSymbol,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final incoming = tx.direction == consts.txDirectionIncoming;
    final coinRate = fiatRate.rateFor(asset.coinSymbol);
    final amount = displayAmount(tx.amountBaseUnits, asset.baseUnitDecimals);
    final amountFiat = coinRate != null ? amount * coinRate : null;
    final confirmed = asset.isTxConfirmed(tx);
    final date = DateTime.fromMillisecondsSinceEpoch(tx.timestamp * 1000);
    final amountColor = incoming ? BrandColors.success : BrandColors.ink;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: showDivider
            ? BoxDecoration(
                border: Border(bottom: BorderSide(color: BrandColors.surfaceTinted)),
              )
            : null,
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            TxActivityIcon(asset: asset, incoming: incoming),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    incoming ? i18n.coinHomeReceived : i18n.coinHomeSent,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                      color: BrandColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (!confirmed) ...[
                        Icon(Icons.hourglass_top_rounded, size: 12, color: BrandColors.warning),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        // Default (en) symbols: initializeDateFormatting isn't wired, so a
                        // locale arg would throw for pt.
                        '${DateFormat('HH:mm').format(date)} · ${asset.assetName}',
                        style: TextStyle(fontSize: 11, height: 1.3, color: BrandColors.inkMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${incoming ? '+' : '−'}${formatAmount(amount, asset.decimals, symbol: asset.coinSymbol)}',
                  style: TextStyle(
                    fontFamily: 'Ubuntu Mono',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: amountColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (amountFiat != null && !fiatRate.isDisabled) ...[
                  const SizedBox(height: 2),
                  Text(
                    formatFiat(amountFiat, fiatSymbol),
                    style: TextStyle(
                      fontFamily: 'Ubuntu Mono',
                      fontSize: 11,
                      height: 1.3,
                      color: BrandColors.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The asset's chain tile with a small direction badge (receive / send).
class TxActivityIcon extends StatelessWidget {
  final CryptoWallet asset;
  final bool incoming;

  const TxActivityIcon({super.key, required this.asset, required this.incoming});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CoinMark(coinSymbol: asset.coinSymbol, iconAsset: asset.iconAsset, size: 36),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 17,
              height: 17,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BrandColors.paper,
                shape: BoxShape.circle,
                border: Border.all(color: BrandColors.hairline, width: 1.5),
              ),
              child: Icon(
                incoming ? Icons.south : Icons.north,
                size: 10,
                color: incoming ? BrandColors.success : BrandColors.cinnamon,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
