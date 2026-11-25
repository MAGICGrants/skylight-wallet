import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/l10n/shared_strings.dart';
import 'package:skylight_wallet/screens/receive_address.dart';
import 'package:wallet_domain/wallet_domain.dart' show AddressLabelModel, CryptoWallet, TxDetails;
import 'package:wallet_ui/wallet_ui.dart' show TxDetailsSheetLabels, showTxDetailsSheet;

/// The tx-details popup is the shared brand bottom sheet in wallet-core
/// (`wallet_ui`), localization-agnostic. This adapter keeps the app's call
/// site unchanged and supplies Skylight's translated strings (incl. the status
/// banner), and the user's address labels for a received transaction's Received
/// At, each opening that subaddress's own screen.
class TxDetailsDialog {
  static void show(BuildContext context, CryptoWallet wallet, TxDetails txDetails) {
    final i18n = AppLocalizations.of(context)!;
    final labels = context.read<AddressLabelModel>();
    final navigator = Navigator.of(context);
    showTxDetailsSheet(
      context: context,
      wallet: wallet,
      tx: txDetails,
      addressLabel: (address) => labels.labelFor(wallet.coinSymbol, address),
      onOpenAddress: (address) async {
        final used = await wallet.loadUsedReceiveAddresses();
        for (final u in used) {
          if (u.address != address) continue;
          await navigator.pushNamed('/receive_address', arguments: ReceiveAddressArgs(used: u));
          return;
        }
      },
      labels: TxDetailsSheetLabels(
        title: i18n.shared.txDetailsTitle,
        hash: i18n.shared.txDetailsHashLabel,
        amount: i18n.shared.amount,
        networkFee: i18n.shared.networkFee,
        timeAndDate: i18n.shared.txDetailsTimeAndDateLabel,
        confirmationHeight: i18n.shared.txDetailsConfirmationHeightLabel,
        confirmations: i18n.shared.txDetailsConfirmationsLabel,
        viewKey: i18n.shared.txDetailsViewKeyLabel,
        recipients: i18n.shared.txDetailsRecipientsLabel,
        changeRecipient: i18n.shared.txDetailsChangeRecipientLabel,
        close: i18n.shared.close,
        copied: i18n.shared.copiedToClipboard,
        received: i18n.shared.coinHomeReceived,
        sent: i18n.shared.coinHomeSent,
        copyHint: i18n.shared.txDetailsCopyHint,
        failed: i18n.shared.txDetailsFailed,
        unknownStatus: i18n.shared.txDetailsUnknownStatus,
        receivedAt: i18n.shared.txDetailsReceivedAtLabel,
        unconfirmed: i18n.shared.unconfirmed,
      ),
    );
  }
}
