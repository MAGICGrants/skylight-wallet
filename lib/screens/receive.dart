import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';
import 'package:wallet_monero/wallet_monero.dart' show MoneroWallet;

class ReceiveScreenArgs {
  final String coinSymbol;

  ReceiveScreenArgs({required this.coinSymbol});
}

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

  void _copyAddress(String address) {
    final i18n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.addressCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final args = ModalRoute.of(context)?.settings.arguments as ReceiveScreenArgs?;
    final coinSymbol = args?.coinSymbol ?? 'XMR';
    final wallet = context.watch<WalletManager>().getWallet(coinSymbol);

    if (wallet == null) {
      return Scaffold(
        backgroundColor: BrandColors.paper,
        body: SafeArea(
          child: Center(child: Text('Unknown coin: $coinSymbol', style: BrandText.body)),
        ),
      );
    }

    final primaryAddress = wallet.getPrimaryAddress();
    final receiveAddress = wallet.getReceiveAddress();
    final isDemoMode = wallet.connectionAddress == 'demo';

    // Monero-only subaddress UX. For non-Monero coins, fall back to primary.
    final monero = wallet is MoneroWallet ? wallet : null;
    final subSupported = monero?.serverSupportsSubaddresses;
    final unusedIndexSupported = monero?.unusedSubaddressIndexIsSupported;
    final canToggle = monero != null && subSupported == true && !isDemoMode;

    String? address;
    if (monero == null) {
      address = receiveAddress ?? primaryAddress;
    } else if (subSupported == false || isDemoMode) {
      address = primaryAddress;
    } else if (subSupported == true) {
      address = _showSubaddress ? receiveAddress : primaryAddress;
    }

    final showingSubaddress = canToggle && _showSubaddress;
    final ready = address != null;
    final warning = _warning(i18n, monero, subSupported, unusedIndexSupported);

    return Scaffold(
      backgroundColor: BrandColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: BrandScreenHeader(
                    onBack: () => Navigator.pop(context),
                    center: Text(i18n.receiveTitle, style: BrandText.appBar.copyWith(fontSize: 16)),
                    action: _isMobile
                        ? IconCircleButton(
                            icon: Icons.ios_share,
                            onPressed: ready
                                ? () => SharePlus.instance.share(ShareParams(text: address!))
                                : null,
                          )
                        : null,
                  ),
                ),
                Expanded(
                  child: !ready
                      ? Center(child: CircularProgressIndicator(color: BrandColors.cinnamon))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
                          children: [
                            _CoinCard(wallet: wallet),
                            if (canToggle) ...[
                              const SizedBox(height: 14),
                              BrandSegmented(
                                dense: true,
                                labels: [i18n.receiveSubaddressTab, i18n.receivePrimaryTab],
                                selectedIndex: _showSubaddress ? 0 : 1,
                                onSelect: (i) => setState(() => _showSubaddress = i == 0),
                              ),
                            ],
                            const SizedBox(height: 14),
                            _QrCard(
                              address: address,
                              heading: _heading(i18n, wallet, monero, showingSubaddress),
                              onTap: () => _copyAddress(address!),
                            ),
                            if (warning != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                warning,
                                textAlign: TextAlign.center,
                                style: BrandText.caption.copyWith(
                                  color: BrandColors.warning,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            BrandButton(
                              label: i18n.receiveCopyAddress,
                              icon: Icons.copy_outlined,
                              onPressed: () => _copyAddress(address!),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _heading(
    AppLocalizations i18n,
    CryptoWallet wallet,
    MoneroWallet? monero,
    bool showingSubaddress,
  ) {
    if (showingSubaddress) {
      final index = monero?.unusedSubaddressIndex;
      return index != null ? '${i18n.receiveSubaddressTab} #$index' : i18n.receiveSubaddressTab;
    }
    return i18n.receiveAddressHeading(wallet.blockchainName);
  }

  String? _warning(
    AppLocalizations i18n,
    MoneroWallet? monero,
    bool? subSupported,
    bool? unusedIndexSupported,
  ) {
    if (monero == null) return null;
    if (subSupported == false) return i18n.receiveServerNoSubaddressesWarn;
    if (subSupported == true && !_showSubaddress) return i18n.receivePrimaryAddressWarn;
    if (subSupported == true && _showSubaddress && unusedIndexSupported == false) {
      return i18n.receiveMaxSubaddressesReachedWarn;
    }
    return null;
  }
}

class _CoinCard extends StatelessWidget {
  final CryptoWallet wallet;
  const _CoinCard({required this.wallet});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    return BrandCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CoinMark(coinSymbol: wallet.coinSymbol, iconAsset: wallet.iconAsset, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The chain, not the asset: one address here receives every
                // asset on it (an Ethereum address takes both Ether and Dai).
                Text(
                  wallet.blockchainName,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                    color: BrandColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  i18n.receiveBlockchainSubtitle(wallet.blockchainName),
                  style: BrandText.caption.copyWith(fontSize: 11.5, color: BrandColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  final String address;
  final String heading;
  final VoidCallback onTap;

  const _QrCard({required this.address, required this.heading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BrandCard(
      radius: 22,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            // The QR sits on a fixed white card so it scans, so its modules must
            // stay dark in both themes — the themed ink goes light in dark mode.
            child: QrImageView(
              data: address,
              size: 200,
              padding: EdgeInsets.zero,
              eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF2C170C)),
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF2C170C),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SectionHeader(label: heading, padding: const EdgeInsets.only(bottom: 9)),
          GestureDetector(
            onTap: onTap,
            child: Text(
              address,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Ubuntu Mono',
                fontSize: 12.5,
                height: 1.7,
                color: BrandColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
