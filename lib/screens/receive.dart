import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/l10n/shared_strings.dart';
import 'package:skylight_wallet/models/app_wallet.dart';
import 'package:skylight_wallet/screens/desktop/home_shell.dart';
import 'package:skylight_wallet/screens/desktop/receive_view.dart';
import 'package:skylight_wallet/screens/receive_address.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/platform.dart';
import 'package:skylight_wallet/util/qr_brightness.dart';
import 'package:skylight_wallet/util/secure_clipboard.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart'
    show AddressLabelModel, CryptoWallet, UsedReceiveAddress;

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

/// The tabs, in order: the next unused subaddress, the primary address, and
/// every used subaddress (the Labeled tab).
enum _Tab { subaddress, primary, labeled }

class _ReceiveScreenState extends State<ReceiveScreen> with QrBrightness {
  var _tab = _Tab.subaddress;

  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  void _copyAddressToClipboard(String address) {
    final i18n = AppLocalizations.of(context)!;
    SecureClipboard.copy(address);
    showCopyToast(context, i18n.shared.addressCopied);
  }

  /// Opens the system share sheet on [address], anchored at [origin].
  ///
  /// [origin] is the share button's rect. iOS presents the sheet as a popover
  /// pointing at it and share_plus rejects the call without one, so dropping it
  /// left the button doing nothing at all. Awaited and caught for the same
  /// reason: a fire-and-forget share turns every failure into silence.
  Future<void> _share(String address, Rect? origin) async {
    final i18n = AppLocalizations.of(context)!;
    final toast = BrandToast.of(context);
    try {
      await SharePlus.instance.share(ShareParams(text: address, sharePositionOrigin: origin));
    } catch (error) {
      log(LogLevel.error, 'Address share failed (origin=${origin ?? 'none'}): $error');
      toast.show(i18n.shared.receiveShareError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final wallet = appWalletOf(context, listen: true);
    final primaryAddress = wallet.getPrimaryAddress();
    final isDemoMode = wallet.connectionAddress == 'demo';
    // The address and the index that labels it, as one value: read separately
    // they can name different subaddresses.
    final sub = isDemoMode ? null : wallet.unusedSubaddress;
    final subSupported = wallet.serverSupportsSubaddresses;
    // The tabs need a subaddress to show. Until there is one (the server has
    // not answered yet, or cannot be reached at all) the primary address is
    // shown: every server scans it. Waiting for the subaddress instead spun
    // forever with no connection.
    final canToggle = subSupported == true && sub != null;
    final tab = canToggle ? _tab : _Tab.primary;

    String? address;
    if (tab == _Tab.subaddress) {
      address = sub!.address;
    } else if (primaryAddress.isNotEmpty) {
      address = primaryAddress;
    }

    final ready = address != null;
    final warning = tab == _Tab.labeled
        ? null
        : _warning(i18n, wallet, isDemoMode, subSupported, sub, tab);
    final qrHeading = tab == _Tab.subaddress
        ? '${i18n.shared.receiveSubaddressTab} #${sub!.index}'
        : i18n.shared.receiveAddressHeading('Monero');
    final tabLabels = canToggle
        ? [
            i18n.shared.receiveSubaddressTab,
            i18n.shared.receivePrimaryTab,
            i18n.shared.receiveLabeledTab,
          ]
        : null;
    void selectTab(int index) {
      final next = _Tab.values[index];
      // The Labeled tab has no QR: one left enlarged would hold the screen at
      // full brightness behind the list.
      if (next == _Tab.labeled && qrEnlarged) toggleQr();
      setState(() => _tab = next);
    }

    final engine = xmrWallet(context);
    final labeled = tab == _Tab.labeled && engine != null ? _LabeledTab(wallet: engine) : null;

    if (isDesktop) {
      return DesktopShell(
        active: DesktopNav.home,
        child: DesktopReceiveView(
          title: i18n.shared.receiveTitle,
          backLabel: i18n.navigationBarWallet,
          copyLabel: i18n.shared.receiveCopyAddress,
          qrHint: i18n.receiveQrHint,
          ready: ready,
          address: address ?? '',
          qrHeading: ready ? qrHeading : '',
          tabLabels: tabLabels,
          selectedTab: tab.index,
          onSelectTab: selectTab,
          warning: warning,
          onCopy: () => _copyAddressToClipboard(address!),
          onBack: () => Navigator.of(context).pop(),
          tabBody: labeled,
        ),
      );
    }

    return ReceiveView(
      labels: ReceiveLabels(
        title: i18n.shared.receiveTitle,
        copyAddress: i18n.shared.receiveCopyAddress,
        enlargeQr: i18n.shared.receiveEnlargeQr,
        shrinkQr: i18n.shared.receiveShrinkQr,
      ),
      onBack: () => Navigator.of(context).pop(),
      onShare: _isMobile ? (origin) => _share(address!, origin) : null,
      ready: ready,
      // Monero-only app: no coin card (would just say "Monero" redundantly).
      coinSymbol: 'XMR',
      iconAsset: 'assets/icons/monero.svg',
      coinName: null,
      blockchainSubtitle: null,
      tabLabels: tabLabels,
      selectedTab: tab.index,
      onSelectTab: selectTab,
      address: address ?? '',
      qrHeading: qrHeading,
      warning: warning,
      onCopy: () => _copyAddressToClipboard(address!),
      qrEnlarged: qrEnlarged,
      onToggleQr: QrBrightness.canBrighten ? toggleQr : null,
      tabBody: labeled,
    );
  }

  String? _warning(
    AppLocalizations i18n,
    AppWallet wallet,
    bool isDemoMode,
    bool? subSupported,
    ({int index, String address})? sub,
    _Tab tab,
  ) {
    if (isDemoMode) return null;
    if (subSupported == false) return i18n.shared.receiveServerNoSubaddressesWarn;
    if (sub == null) return i18n.shared.receiveSubaddressUnavailableWarn;
    if (tab == _Tab.primary) return i18n.shared.receivePrimaryAddressWarn;
    if (wallet.unusedSubaddressIndexIsSupported == false) {
      return i18n.shared.receiveMaxSubaddressesReachedWarn;
    }
    return null;
  }
}

/// The Labeled tab: every used subaddress with its label, from
/// [CryptoWallet.loadUsedReceiveAddresses] (read again only when the history
/// moves) and the [AddressLabelModel].
class _LabeledTab extends StatefulWidget {
  const _LabeledTab({required this.wallet});

  final CryptoWallet wallet;

  @override
  State<_LabeledTab> createState() => _LabeledTabState();
}

class _LabeledTabState extends State<_LabeledTab> {
  Future<List<UsedReceiveAddress>>? _used;
  int? _revision;

  Future<List<UsedReceiveAddress>> _load() {
    final revision = widget.wallet.txHistoryRevision;
    if (_used == null || _revision != revision) {
      _revision = revision;
      _used = widget.wallet.loadUsedReceiveAddresses();
    }
    return _used!;
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    // Watched so the list follows new transactions and label edits.
    appWalletOf(context, listen: true);
    final labels = context.watch<AddressLabelModel>();
    final wallet = widget.wallet;
    final coin = labeledAddressCoinOf(wallet);
    return FutureBuilder<List<UsedReceiveAddress>>(
      future: _load(),
      builder: (context, snapshot) {
        final used = snapshot.hasError ? const <UsedReceiveAddress>[] : snapshot.data;
        return LabeledAddressList(
          strings: i18n.shared,
          coin: coin,
          entries: used == null
              ? null
              : [
                  for (final u in used)
                    (used: u, label: labels.labelFor(wallet.coinSymbol, u.address)),
                ],
          onOpen: (entry) => Navigator.pushNamed(
            context,
            '/receive_address',
            arguments: ReceiveAddressArgs(used: entry.used),
          ),
          onLabel: (entry) => editAddressLabel(context, wallet, entry),
        );
      },
    );
  }
}
