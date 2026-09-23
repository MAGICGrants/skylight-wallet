import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/app_wallet.dart';
import 'package:skylight_wallet/screens/desktop/home_shell.dart';
import 'package:skylight_wallet/screens/desktop/receive_view.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/platform.dart';
import 'package:skylight_wallet/util/secure_clipboard.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  var _showSubaddress = true;
  var _previousBrightness = 0.0;

  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    if (_isMobile) _setBrightnessToMax();
  }

  @override
  void dispose() {
    if (_isMobile) _setBrightnessToNormal();
    super.dispose();
  }

  Future<void> _setBrightnessToMax() async {
    _previousBrightness = await ScreenBrightness().system;
    await ScreenBrightness().setApplicationScreenBrightness(1.0);
  }

  Future<void> _setBrightnessToNormal() async {
    await ScreenBrightness().setApplicationScreenBrightness(_previousBrightness);
  }

  void _copyAddressToClipboard(String address) {
    final i18n = AppLocalizations.of(context)!;
    SecureClipboard.copy(address);
    showCopyToast(context, i18n.addressCopied);
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
      toast.show(i18n.receiveShareError);
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
    final canToggle = subSupported == true && !isDemoMode;

    String? address;
    if (subSupported == false || isDemoMode) {
      address = primaryAddress;
    }
    if (subSupported == true) {
      address = _showSubaddress ? sub?.address : primaryAddress;
    }

    final ready = (subSupported != null || isDemoMode) && address != null;
    final warning = _warning(i18n, wallet, subSupported);
    final qrHeading = canToggle && _showSubaddress
        ? (sub != null ? '${i18n.receiveSubaddressTab} #${sub.index}' : i18n.receiveSubaddressTab)
        : i18n.receiveAddressHeading('Monero');

    if (isDesktop) {
      return DesktopShell(
        active: DesktopNav.home,
        child: DesktopReceiveView(
          title: i18n.receiveTitle,
          backLabel: i18n.navigationBarWallet,
          copyLabel: i18n.receiveCopyAddress,
          qrHint: i18n.receiveQrHint,
          ready: ready,
          address: address ?? '',
          qrHeading: ready ? qrHeading : '',
          tabLabels: canToggle ? [i18n.receiveSubaddressTab, i18n.receivePrimaryTab] : null,
          selectedTab: _showSubaddress ? 0 : 1,
          onSelectTab: (index) => setState(() => _showSubaddress = index == 0),
          warning: warning,
          onCopy: () => _copyAddressToClipboard(address!),
          onBack: () => Navigator.of(context).pop(),
        ),
      );
    }

    return ReceiveView(
      labels: ReceiveLabels(title: i18n.receiveTitle, copyAddress: i18n.receiveCopyAddress),
      onBack: () => Navigator.of(context).pop(),
      onShare: _isMobile ? (origin) => _share(address!, origin) : null,
      ready: ready,
      // Monero-only app: no coin card (would just say "Monero" redundantly).
      coinSymbol: 'XMR',
      iconAsset: 'assets/icons/monero.svg',
      coinName: null,
      blockchainSubtitle: null,
      tabLabels: canToggle ? [i18n.receiveSubaddressTab, i18n.receivePrimaryTab] : null,
      selectedTab: _showSubaddress ? 0 : 1,
      onSelectTab: (index) => setState(() => _showSubaddress = index == 0),
      address: address ?? '',
      qrHeading: qrHeading,
      warning: warning,
      onCopy: () => _copyAddressToClipboard(address!),
    );
  }

  String? _warning(AppLocalizations i18n, AppWallet wallet, bool? subSupported) {
    if (subSupported == false) return i18n.receiveServerNoSubaddressesWarn;
    if (subSupported == true && !_showSubaddress) return i18n.receivePrimaryAddressWarn;
    if (subSupported == true &&
        _showSubaddress &&
        wallet.unusedSubaddressIndexIsSupported == false) {
      return i18n.receiveMaxSubaddressesReachedWarn;
    }
    return null;
  }
}
