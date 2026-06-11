import 'package:flutter/material.dart';

import 'package:skylight_wallet/services/tor_service.dart';
import 'package:skylight_wallet/wallets/crypto_wallet.dart';

enum ConnectionIndicatorState { ok, loading, error }

/// Single source of truth for a wallet's connection indicator state, shared by
/// the coin-home header and the wallet-home coin rows.
ConnectionIndicatorState connectionIndicatorStateFor(CryptoWallet wallet) {
  if (wallet.connectionAddress.isEmpty) return ConnectionIndicatorState.error;
  if (wallet.isConnected && wallet.isSynced && (wallet.syncedHeight ?? 0) > 0) {
    return ConnectionIndicatorState.ok;
  }
  if (wallet.usingTor && TorService.sharedInstance.status == TorConnectionStatus.connecting ||
      !wallet.hasAttemptedConnection ||
      wallet.isConnected && !wallet.isSynced ||
      wallet.isConnected && wallet.isSynced && (wallet.syncedHeight ?? 0) == 0) {
    return ConnectionIndicatorState.loading;
  }
  return ConnectionIndicatorState.error;
}

/// Compact connection status shown next to a coin title (wallet home rows)
/// or in coin home header: invisible when OK, spinner when connecting, red
/// warning (same logical size as the fiat API triangle) when problematic.
class ConnectionStatusIndicator extends StatelessWidget {
  /// Matches [Icons.warning_rounded] in total balance fiat error indicator.
  static const double indicatorSize = 18;

  const ConnectionStatusIndicator({
    super.key,
    required this.state,
    required this.tooltipMessage,
  });

  final ConnectionIndicatorState state;
  final String tooltipMessage;

  @override
  Widget build(BuildContext context) {
    if (state == ConnectionIndicatorState.ok) {
      return SizedBox.shrink();
    }

    final Widget indicator = state == ConnectionIndicatorState.loading
        ? SizedBox(
            width: indicatorSize,
            height: indicatorSize,
            child: Padding(
              padding: EdgeInsets.all(2),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : Icon(Icons.warning_rounded, size: indicatorSize, color: Colors.red);

    return Tooltip(
      message: tooltipMessage,
      child: indicator,
    );
  }
}
