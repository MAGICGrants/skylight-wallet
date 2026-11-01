import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallet_domain/wallet_domain.dart' show WalletManager;
import 'package:wallet_infra/wallet_infra.dart' show SyncFrequency;

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/l10n/shared_strings.dart';
import 'package:skylight_wallet/services/foreground_sync_service.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

/// The Sync Frequency sheet's strings. Periodic names the Monero node's limits,
/// which differ by platform: iOS can only wait for a charger, not for WiFi.
SyncFrequencyLabels syncFrequencyLabels(AppLocalizations i18n) => SyncFrequencyLabels(
  title: i18n.shared.settingsSyncFrequencyLabel,
  subtitle: i18n.syncFrequencySheetSubtitle,
  continuous: i18n.shared.syncFrequencyContinuous,
  continuousDesc: i18n.syncFrequencyContinuousDesc,
  periodic: i18n.shared.syncFrequencyPeriodic,
  periodicDesc: Platform.isIOS ? i18n.syncFrequencyPeriodicDescIos : i18n.syncFrequencyPeriodicDesc,
  off: i18n.shared.syncFrequencyOff,
  offDesc: i18n.shared.syncFrequencyOffDesc,
  save: i18n.shared.save,
  cancel: i18n.shared.cancel,
);

/// Opens Sync Frequency and applies a saved choice: the view-only material, the
/// Continuous Sync service and the background tasks (`applySyncFrequency`).
/// Resolves to the saved choice, or null when the user cancelled.
Future<SyncFrequency?> showSyncFrequencySettings(BuildContext context) async {
  final labels = syncFrequencyLabels(AppLocalizations.of(context)!);
  final manager = Provider.of<WalletManager>(context, listen: false);
  final frequency = await showSyncFrequencySheet(context, labels: labels);
  if (frequency != null) await applySyncFrequency(manager, frequency);
  return frequency;
}
