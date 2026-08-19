import 'package:flutter/material.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:wallet_domain/wallet_domain.dart' show CryptoWallet, TxDetails;
import 'package:wallet_ui/wallet_ui.dart' as ui;

/// The tx-details popup lives in wallet-core (`wallet_ui`, D24), localization-
/// agnostic. This adapter keeps the app's call site unchanged and supplies
/// skylight's translated strings.
class TxDetailsDialog {
  static void show(BuildContext context, CryptoWallet wallet, TxDetails txDetails) {
    final i18n = AppLocalizations.of(context)!;
    ui.TxDetailsDialog.show(
      context,
      wallet,
      txDetails,
      ui.TxDetailsLabels(
        title: i18n.txDetailsTitle,
        hash: i18n.txDetailsHashLabel,
        amount: i18n.amount,
        networkFee: i18n.networkFee,
        timeAndDate: i18n.txDetailsTimeAndDateLabel,
        confirmationHeight: i18n.txDetailsConfirmationHeightLabel,
        confirmations: i18n.txDetailsConfirmationsLabel,
        viewKey: i18n.txDetailsViewKeyLabel,
        recipients: i18n.txDetailsRecipientsLabel,
        changeRecipient: i18n.txDetailsChangeRecipientLabel,
        close: i18n.close,
        copied: i18n.copiedToClipboard,
      ),
    );
  }
}
