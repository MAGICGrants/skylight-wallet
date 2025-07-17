import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';

class TxDetailsScreen extends StatelessWidget {
  const TxDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final txDetails = ModalRoute.of(context)!.settings.arguments as TxDetails;
    final amountSent = txDetails.amount.toString();
    final fee = txDetails.fee.toString();

    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      txDetails.timestamp * 1000,
    );

    final dateFormatted = DateFormat.yMMMMd(locale.toString()).format(dateTime);
    final timeFormatted = DateFormat.jm(locale.toString()).format(dateTime);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            spacing: 10,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hash', style: TextStyle(fontWeight: FontWeight.bold)),
                  GestureDetector(
                    child: Text(
                      txDetails.hash,
                      style: TextStyle(fontFamily: 'monospace'),
                    ),
                    onTap: () =>
                        Clipboard.setData(ClipboardData(text: txDetails.hash)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('$amountSent XMR'),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fee', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('$fee XMR'),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Time and Date',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('$dateFormatted $timeFormatted'),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confirmation Height',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(txDetails.height.toString()),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confirmations',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(txDetails.confirmations.toString()),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'View Key',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    child: Text(
                      txDetails.key,
                      style: TextStyle(fontFamily: 'monospace'),
                    ),
                    onTap: () =>
                        Clipboard.setData(ClipboardData(text: txDetails.key)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recipients',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ListView.separated(
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
                            ),
                            onTap: () => Clipboard.setData(
                              ClipboardData(text: recipient.address),
                            ),
                          ),
                          Text('$amountStr XMR'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
