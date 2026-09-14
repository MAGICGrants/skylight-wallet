import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/app_wallet.dart';
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

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final wallet = appWalletOf(context, listen: true);
    final primaryAddress = wallet.getPrimaryAddress();
    final subaddress = wallet.getUnusedSubaddress();
    final isDemoMode = wallet.connectionAddress == 'demo';
    final subSupported = wallet.serverSupportsSubaddresses;
    final canToggle = subSupported == true && !isDemoMode;

    String? address;
    if (subSupported == false || isDemoMode) {
      address = primaryAddress;
    }
    if (subSupported == true) {
      address = _showSubaddress ? subaddress : primaryAddress;
    }

    final ready = (subSupported != null || isDemoMode) && address != null;
    final warning = _warning(i18n, wallet, subSupported);

    return ReceiveView(
      labels: ReceiveLabels(title: i18n.receiveTitle, copyAddress: i18n.receiveCopyAddress),
      onBack: () => Navigator.of(context).pop(),
      onShare: _isMobile ? () => SharePlus.instance.share(ShareParams(text: address!)) : null,
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
      qrHeading: canToggle && _showSubaddress
          ? (wallet.unusedSubaddressIndex != null
                ? '${i18n.receiveSubaddressTab} #${wallet.unusedSubaddressIndex}'
                : i18n.receiveSubaddressTab)
          : i18n.receiveAddressHeading('Monero'),
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
