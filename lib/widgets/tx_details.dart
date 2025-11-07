import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/wallet_model.dart';

class TxDetailsDialog {
  static void show(BuildContext context, TxDetails txDetails) {
    showDialog(
      context: context,
      builder: (context) => _TxDetailsDialog(txDetails: txDetails),
    );
  }
}

class _TxDetailsDialog extends StatelessWidget {
  final TxDetails txDetails;

  const _TxDetailsDialog({required this.txDetails});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final amountSent = txDetails.amount.toString();
    final fee = txDetails.fee.toString();

    final dateTime = DateTime.fromMillisecondsSinceEpoch(txDetails.timestamp * 1000);

    final dateFormatted = DateFormat.yMMMMd(locale.toString()).format(dateTime);
    final timeFormatted = DateFormat.jm(locale.toString()).format(dateTime);

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth.clamp(0.0, 500.0);

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
                    constraints: BoxConstraints(maxWidth: 240),
                    child: GestureDetector(
                      child: Text(
                        txDetails.hash,
                        textAlign: TextAlign.end,
                        style: TextStyle(fontFamily: 'monospace'),
                        softWrap: true,
                      ),
                      onTap: () => Clipboard.setData(ClipboardData(text: txDetails.hash)),
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
                Flexible(child: Text('$amountSent XMR', textAlign: TextAlign.end, softWrap: true)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 20,
              children: [
                Text(i18n.networkFee, style: TextStyle(fontWeight: FontWeight.bold)),
                Flexible(child: Text('$fee XMR', textAlign: TextAlign.end, softWrap: true)),
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
                    txDetails.height.toString(),
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
                      constraints: BoxConstraints(maxWidth: 240),
                      child: GestureDetector(
                        child: Text(
                          txDetails.key,
                          textAlign: TextAlign.end,
                          style: TextStyle(fontFamily: 'monospace'),
                          softWrap: true,
                        ),
                        onTap: () => Clipboard.setData(ClipboardData(text: txDetails.key)),
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
                        final amountStr = recipient.amount.toString();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              child: Text(
                                recipient.address,
                                style: TextStyle(fontFamily: 'monospace'),
                                softWrap: true,
                              ),
                              onTap: () =>
                                  Clipboard.setData(ClipboardData(text: recipient.address)),
                            ),
                            Text('$amountStr XMR', softWrap: true),
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
