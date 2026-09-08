import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:wallet_domain/wallet_domain.dart' show CryptoWallet;

import 'package:spice_wallet/theme/brand.dart';
import 'package:spice_wallet/util/connection_address.dart';

enum RoutePillIcon { tor, https, proxy, local, server, electrum }

/// Small route/security pill (TOR · HTTPS · PROXY · LOCAL). Icons are the exact
/// design line marks, tinted to the pill colour. Shared by the connection form
/// and the asset screen's route line.
class RoutePill extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final RoutePillIcon icon;

  /// Icon only, no label — a tighter pill for the syncing row.
  final bool compact;

  const RoutePill({
    super.key,
    required this.label,
    required this.color,
    required this.bg,
    required this.icon,
    this.compact = false,
  });

  String _svg() {
    final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    switch (icon) {
      case RoutePillIcon.tor:
        return '<svg viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2">'
            '<circle cx="12" cy="12" r="8.5"/><ellipse cx="12" cy="12" rx="3.6" ry="8.5"/>'
            '<path d="M3.5 12h17"/></svg>';
      case RoutePillIcon.https:
        return '<svg viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2.2" stroke-linecap="round">'
            '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>';
      case RoutePillIcon.proxy:
        return '<svg viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">'
            '<path d="M4 12h4M16 12h4"/><circle cx="12" cy="12" r="3.2"/></svg>';
      case RoutePillIcon.local:
        return '<svg viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2.2" stroke-linecap="round">'
            '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V7.5a4 4 0 0 1 7-2.6"/></svg>';
      case RoutePillIcon.server:
        return '<svg viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2" stroke-linecap="round">'
            '<rect x="4" y="5" width="16" height="6" rx="1.6"/><rect x="4" y="13" width="16" height="6" rx="1.6"/>'
            '<path d="M7.5 8h.01M7.5 16h.01"/></svg>';
      case RoutePillIcon.electrum:
        // A generic atom (nucleus + electron orbits) for the Electrum server pill
        // — no official logo asset is bundled.
        return '<svg viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="1.5">'
            '<circle cx="12" cy="12" r="1.7" fill="$hex" stroke="none"/>'
            '<ellipse cx="12" cy="12" rx="10" ry="4.3"/>'
            '<ellipse cx="12" cy="12" rx="10" ry="4.3" transform="rotate(60 12 12)"/>'
            '<ellipse cx="12" cy="12" rx="10" ry="4.3" transform="rotate(120 12 12)"/></svg>';
    }
  }

  @override
  Widget build(BuildContext context) {
    final glyph = SvgPicture.string(_svg(), width: 10.5, height: 10.5);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 7, vertical: 4.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6.5)),
      child: compact
          ? glyph
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                glyph,
                const SizedBox(width: 4.5),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Ubuntu Mono',
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.74,
                    color: color,
                  ),
                ),
              ],
            ),
    );
  }
}

/// The route/security pills implied by a connection: a routing pill (TOR/PROXY)
/// when either is in use, then a security pill (HTTPS for a clearnet domain,
/// LOCAL for a LAN host). Empty for a plain public-IP node, which is neither.
List<RoutePill> connectionRoutePills({
  required bool useTor,
  required String proxyPort,
  required String address,
  bool compact = false,
}) {
  final pills = <RoutePill>[];
  if (useTor) {
    pills.add(
      RoutePill(
        label: 'TOR',
        color: BrandColors.purple,
        bg: BrandColors.purpleBg,
        icon: RoutePillIcon.tor,
        compact: compact,
      ),
    );
  } else if (proxyPort.trim().isNotEmpty) {
    pills.add(
      RoutePill(
        label: 'PROXY',
        color: BrandColors.blue,
        bg: BrandColors.blueBg,
        icon: RoutePillIcon.proxy,
        compact: compact,
      ),
    );
  }
  if (addressUsesSsl(address)) {
    pills.add(
      RoutePill(
        label: 'HTTPS',
        color: BrandColors.success,
        bg: BrandColors.successBg,
        icon: RoutePillIcon.https,
        compact: compact,
      ),
    );
  } else if (addressIsLocal(address)) {
    pills.add(
      RoutePill(
        label: 'LOCAL',
        color: BrandColors.inkFaint,
        bg: BrandColors.surfaceMuted,
        icon: RoutePillIcon.local,
        compact: compact,
      ),
    );
  }
  return pills;
}

/// A wallet's connection as pills: transport (TOR/PROXY · HTTPS/LOCAL) then the
/// orange server-kind pill (NODE / LWS) last. Wraps to a new line in tight rows.
/// Renders nothing when there are no pills (e.g. an unconfigured coin).
class ConnectionPills extends StatelessWidget {
  final CryptoWallet wallet;

  /// Icon-only pills on a single non-wrapping row (used beside "x blocks left").
  final bool compact;

  const ConnectionPills({super.key, required this.wallet, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final typePill = connectionTypePill(wallet, compact: compact);
    final pills = <Widget>[
      ...connectionRoutePills(
        useTor: wallet.connectionUseTor,
        proxyPort: wallet.connectionProxyPort,
        address: wallet.connectionAddress,
        compact: compact,
      ),
      if (typePill != null) typePill,
    ];
    if (pills.isEmpty) return const SizedBox.shrink();
    return compact
        ? Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: pills)
        : Wrap(spacing: 6, runSpacing: 6, children: pills);
  }
}

/// The server-kind pill, meant to sit last after the route pills. Bitcoin always
/// speaks Electrum (light-blue pill); Monero shows its mode (orange NODE / LWS).
/// Null for coins with no such distinction (e.g. Ethereum's RPC).
RoutePill? connectionTypePill(CryptoWallet wallet, {bool compact = false}) {
  if (wallet.coinSymbol == 'BTC' || wallet.coinSymbol == 'TBTC') {
    return RoutePill(
      label: 'ELECTRUM',
      color: BrandColors.electrum,
      bg: BrandColors.electrumBg,
      icon: RoutePillIcon.electrum,
      compact: compact,
    );
  }
  final label = switch (wallet.connectionType) {
    'node' => 'NODE',
    'lws' => 'LWS',
    _ => null,
  };
  if (label == null) return null;
  return RoutePill(
    label: label,
    color: BrandColors.orange,
    bg: BrandColors.orangeBg,
    icon: RoutePillIcon.server,
    compact: compact,
  );
}
