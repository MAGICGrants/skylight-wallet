import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/util/amount_units.dart';
import 'package:spice_wallet/util/format.dart';
import 'package:spice_wallet/util/formatting.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

class ConfirmSendScreenArgs {
  final String coinSymbol;
  final PendingTransaction tx;
  final String destinationAddress;
  final String? destinationOpenAlias;
  final String? destinationContactName;

  ConfirmSendScreenArgs({
    required this.coinSymbol,
    required this.tx,
    required this.destinationAddress,
    this.destinationOpenAlias,
    this.destinationContactName,
  });
}

/// Presents the "Confirm Send" review as a brand bottom sheet. Resolves to
/// `true` once the transaction is committed (the caller then routes home), or
/// null if the user dismisses/cancels.
Future<bool?> showConfirmSendSheet(BuildContext context, ConfirmSendScreenArgs args) {
  return showBrandSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ConfirmSendSheet(args: args),
  );
}

class _ConfirmSendSheet extends StatefulWidget {
  final ConfirmSendScreenArgs args;

  const _ConfirmSendSheet({required this.args});

  @override
  State<_ConfirmSendSheet> createState() => _ConfirmSendSheetState();
}

class _ConfirmSendSheetState extends State<_ConfirmSendSheet> {
  static const _highFeeThreshold = 0.10;

  bool _isLoading = false;

  Future<void> _confirmSend() async {
    final i18n = AppLocalizations.of(context)!;
    final manager = Provider.of<WalletManager>(context, listen: false);
    final wallet = manager.getWallet(widget.args.coinSymbol);
    if (wallet == null) return;

    setState(() => _isLoading = true);

    try {
      await wallet.commitTx(widget.args.tx, widget.args.destinationAddress);
      if (mounted) Navigator.of(context).pop(true);
      return;
    } on FormatException catch (error) {
      var errorMsg = error.toString().replaceFirst('FormatException: ', '');
      if (error.toString().contains('HTTP error code 500')) {
        errorMsg = 'Failed to send transaction. You might have insufficient unlocked balance.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    } catch (error) {
      log(LogLevel.error, error.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.unknownError)));
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  /// Fee as a fraction of the amount, or null when it can't be determined
  /// (token send with no fiat rate). Same-currency fees compare directly;
  /// foreign (token) fees compare in fiat.
  double? _feeToAmountRatio(
    FiatRateModel fiatRate,
    CryptoWallet? wallet,
    double amount,
    double fee,
    bool feeIsForeign,
    String feeSymbol,
  ) {
    if (amount <= 0) return null;
    if (!feeIsForeign) return fee / amount;

    final amountRate = fiatRate.rateFor(wallet?.coinSymbol ?? widget.args.coinSymbol);
    final feeRate = fiatRate.rateFor(feeSymbol);
    if (amountRate == null || feeRate == null) return null;

    final amountFiat = amount * amountRate;
    if (amountFiat <= 0) return null;
    return (fee * feeRate) / amountFiat;
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final args = widget.args;
    final fiatRate = context.watch<FiatRateModel>();
    final fiatSymbol = fiatRate.fiatCode == 'EUR' ? '€' : '\$';
    final wallet = context.watch<WalletManager>().getWallet(args.coinSymbol);

    final decimals = wallet?.decimals ?? 12;
    final coinSymbol = wallet?.coinSymbol ?? args.coinSymbol;
    final feeDecimals = wallet?.feeDecimals ?? decimals;
    final feeSymbol = wallet?.feeCoinSymbol ?? coinSymbol;
    final feeIsForeign = wallet?.feeIsForeign ?? false;

    final amount = wallet == null
        ? 0.0
        : displayAmount(args.tx.amountBaseUnits, wallet.baseUnitDecimals);
    final fee = wallet == null
        ? 0.0
        : displayAmount(args.tx.feeBaseUnits, wallet.feeBaseUnitDecimals);

    final coinRate = fiatRate.rateFor(coinSymbol);
    final amountFiat = coinRate != null ? amount * coinRate : null;
    // The fee is in ETH for tokens; its fiat can't use the token's rate, so omit it.
    final networkFeeFiat = coinRate != null && !feeIsForeign ? fee * coinRate : null;

    final feeRatio = _feeToAmountRatio(fiatRate, wallet, amount, fee, feeIsForeign, feeSymbol);
    final showHighFeeWarning = feeRatio != null && feeRatio > _highFeeThreshold;

    final rows = <Widget>[
      _detailRow(
        i18n.amount,
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CoinMark(coinSymbol: coinSymbol, iconAsset: wallet?.iconAsset ?? '', size: 22),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    '${amount.toStringAsFixed(decimals)} $coinSymbol',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontFamily: 'Ubuntu Mono',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: BrandColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            if (amountFiat != null) ...[
              const SizedBox(height: 4),
              _fiatText(formatFiat(amountFiat, fiatSymbol)),
            ],
          ],
        ),
      ),
      _detailRow(
        i18n.networkFee,
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${fee.toStringAsFixed(feeDecimals)} $feeSymbol',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: 'Ubuntu Mono',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: BrandColors.ink,
              ),
            ),
            if (networkFeeFiat != null) ...[
              const SizedBox(height: 4),
              _fiatText(formatFiat(networkFeeFiat, fiatSymbol)),
            ],
          ],
        ),
      ),
      if (args.destinationOpenAlias != null)
        _detailRow(
          'OpenAlias',
          Text(
            args.destinationOpenAlias!,
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 12.5, color: BrandColors.ink),
          ),
        ),
      _detailRow(
        i18n.address,
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _verifiableAddress(args.destinationAddress),
            if (args.destinationContactName != null) ...[
              const SizedBox(height: 4),
              _fiatText('(${args.destinationContactName})', mono: false),
            ],
          ],
        ),
      ),
    ];

    return PopScope(
      // Block drag/back dismissal while the commit is in flight.
      canPop: !_isLoading,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.86),
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SheetIcon(
                            icon: Icons.north_east,
                            bg: BrandColors.surfaceAccent,
                            color: BrandColors.cinnamonDeep,
                          ),
                          const SizedBox(width: 11),
                          Expanded(child: Text(i18n.confirmSendTitle, style: BrandText.sheetTitle)),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        i18n.confirmSendDescription,
                        style: BrandText.bodyMuted.copyWith(fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: BrandCard(
                            radius: 18,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Column(
                              children: [
                                for (var i = 0; i < rows.length; i++) ...[
                                  if (i != 0) Container(height: 1, color: BrandColors.hairline),
                                  rows[i],
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (showHighFeeWarning)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                            child: _highFeeWarning(i18n, feeRatio),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                  child: Column(
                    children: [
                      BrandButton(
                        label: i18n.sendSendButton,
                        icon: Icons.north_east,
                        iconTrailing: true,
                        loading: _isLoading,
                        onPressed: _confirmSend,
                      ),
                      const SizedBox(height: 2),
                      BrandButton.ghost(
                        label: i18n.cancel,
                        color: BrandColors.inkMuted,
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: BrandColors.ink,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
        ],
      ),
    );
  }

  Widget _fiatText(String text, {bool mono = true}) {
    return Text(
      text,
      textAlign: TextAlign.end,
      style: TextStyle(
        fontFamily: mono ? 'Ubuntu Mono' : null,
        fontSize: 11.5,
        color: BrandColors.inkMuted,
      ),
    );
  }

  /// Address with its first/last chunks bold and the middle de-emphasised, so
  /// the parts users actually verify stand out.
  Widget _verifiableAddress(String address) {
    final parts = addressDisplayParts(address);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 210),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontFamily: 'Ubuntu Mono',
            fontSize: 12.5,
            height: 1.5,
            color: BrandColors.ink,
          ),
          children: [
            TextSpan(
              text: parts.prefix,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (parts.middle.isNotEmpty)
              TextSpan(
                text: parts.middle,
                style: TextStyle(fontWeight: FontWeight.w300, color: BrandColors.inkMuted),
              ),
            TextSpan(
              text: parts.suffix,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        textAlign: TextAlign.end,
      ),
    );
  }

  Widget _highFeeWarning(AppLocalizations i18n, double feeRatio) {
    // Split the localized string on the {percent} placeholder so the percentage
    // can be bolded regardless of locale. Use a sentinel (not a space) as the
    // placeholder value, since the sentence itself contains spaces.
    const token = '\u0000';
    final parts = i18n.confirmSendHighFeeWarning(token).split(token);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: BrandColors.warningBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: BrandColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 12.5, height: 1.4, color: BrandColors.ink),
                children: [
                  TextSpan(text: parts.first),
                  TextSpan(
                    text: '${(feeRatio * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (parts.length > 1) TextSpan(text: parts.last),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
