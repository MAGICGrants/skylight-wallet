import 'package:flutter/material.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/l10n/shared_strings.dart';
import 'package:wallet_domain/wallet_domain.dart' show CryptoWallet, TxDetails;
import 'package:wallet_ui/wallet_ui.dart' show TxDetailsSheetLabels, showTxDetailsSheet;

/// The tx-details popup is the shared brand bottom sheet in wallet-core
/// (`wallet_ui`), localization-agnostic. This adapter keeps the app's call
/// site unchanged and supplies Skylight's translated strings (incl. the status
/// banner).
class TxDetailsDialog {
  static void show(BuildContext context, CryptoWallet wallet, TxDetails txDetails) {
    final i18n = AppLocalizations.of(context)!;
    showTxDetailsSheet(
      context: context,
      wallet: wallet,
      tx: txDetails,
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
