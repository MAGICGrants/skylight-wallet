import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/util/secure_clipboard.dart';
import 'package:skylight_wallet/wallets/crypto_wallet.dart';

class TxDetailsDialog {
  static void show(BuildContext context, CryptoWallet wallet, TxDetails txDetails) {
    showDialog(
      context: context,
      builder: (context) => _TxDetailsDialog(wallet: wallet, txDetails: txDetails),
    );
  }
}

/// Splits [s] into [lines] newline-separated segments of near-equal length
/// (sizes differ by at most one char).
String _chunkIntoLines(String s, int lines) {
  if (lines <= 1 || s.length <= lines) return s;
  final baseSize = s.length ~/ lines;
  final remainder = s.length % lines;
  final buffer = StringBuffer();
  var start = 0;
  for (var i = 0; i < lines; i++) {
    final size = baseSize + (i < remainder ? 1 : 0);
    final end = start + size;
    if (i > 0) buffer.write('\n');
    buffer.write(s.substring(start, end));
    start = end;
  }
  return buffer.toString();
}

class _TxDetailsDialog extends StatelessWidget {
  final CryptoWallet wallet;
  final TxDetails txDetails;

  const _TxDetailsDialog({required this.wallet, required this.txDetails});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final amountSent = txDetails.amount.toStringAsFixed(wallet.decimals);
    final fee = txDetails.fee.toStringAsFixed(wallet.feeDecimals);

    final dateTime = DateTime.fromMillisecondsSinceEpoch(txDetails.timestamp * 1000);

    final dateFormatted = DateFormat.yMMMMd(locale.toString()).format(dateTime);
    final timeFormatted = DateFormat.jm(locale.toString()).format(dateTime);

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth.clamp(0.0, 500.0);

    final addressLines = wallet.coinSymbol == 'XMR' ? 3 : 2;

    return AlertDialog(
      constraints: BoxConstraints.tightFor(width: dialogWidth),
      insetPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      title: Text(i18n.txDetailsTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 20,
              children: [
                Text(i18n.txDetailsHashLabel, style: TextStyle(fontWeight: FontWeight.bold)),
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 280),
                    child: GestureDetector(
                      child: Text(
                        _chunkIntoLines(txDetails.hash, 3),
                        textAlign: TextAlign.end,
                        style: TextStyle(fontFamily: 'monospace'),
                      ),
                      onTap: () => SecureClipboard.copy(txDetails.hash),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 20,
              children: [
                Text(i18n.amount, style: TextStyle(fontWeight: FontWeight.bold)),
                Flexible(
                  child: Text(
                    '$amountSent ${wallet.coinSymbol}',
                    textAlign: TextAlign.end,
                    softWrap: true,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 20,
              children: [
                Text(i18n.networkFee, style: TextStyle(fontWeight: FontWeight.bold)),
                Flexible(
                  child: Text(
                    '$fee ${wallet.feeCoinSymbol}',
                    textAlign: TextAlign.end,
                    softWrap: true,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 20,
              children: [
                Text(i18n.txDetailsTimeAndDateLabel, style: TextStyle(fontWeight: FontWeight.bold)),
                Flexible(
                  child: Text(
                    '$dateFormatted $timeFormatted',
                    textAlign: TextAlign.end,
                    softWrap: true,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 20,
              children: [
                Text(
                  i18n.txDetailsConfirmationHeightLabel,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Flexible(
                  child: Text(
                    txDetails.height == -1 ? '0' : txDetails.height.toString(),
                    textAlign: TextAlign.end,
                    softWrap: true,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 20,
              children: [
                Text(
                  i18n.txDetailsConfirmationsLabel,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Flexible(
                  child: Text(
                    txDetails.confirmations.toString(),
                    textAlign: TextAlign.end,
                    softWrap: true,
                  ),
                ),
              ],
            ),
            if (txDetails.key.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 20,
                children: [
                  Text(i18n.txDetailsViewKeyLabel, style: TextStyle(fontWeight: FontWeight.bold)),
                  Flexible(
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 280),
                      child: GestureDetector(
                        child: Text(
                          txDetails.key,
                          textAlign: TextAlign.end,
                          style: TextStyle(fontFamily: 'monospace'),
                          softWrap: true,
                        ),
                        onTap: () => SecureClipboard.copy(txDetails.key),
                      ),
                    ),
                  ),
                ],
              ),
            if (txDetails.recipients.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 20,
                children: [
                  Text(
                    i18n.txDetailsRecipientsLabel,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: txDetails.recipients.length,
                      separatorBuilder: (context, index) => SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final recipient = txDetails.recipients[index];
                        final amountStr = recipient.amount.toStringAsFixed(wallet.decimals);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            GestureDetector(
                              child: Container(
                                constraints: BoxConstraints(maxWidth: 280),
                                child: Text(
                                  _chunkIntoLines(recipient.address, addressLines),
                                  style: TextStyle(fontFamily: 'monospace'),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                              onTap: () =>
                                  SecureClipboard.copy(recipient.address),
                            ),
                            Text('$amountStr ${wallet.coinSymbol}', softWrap: true),
                            if (recipient.isChange)
                              Text(
                                i18n.txDetailsChangeRecipientLabel,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n.close))],
    );
  }
}
