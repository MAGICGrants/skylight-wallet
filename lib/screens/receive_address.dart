import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/l10n/shared_strings.dart';
import 'package:skylight_wallet/screens/desktop/home_shell.dart';
import 'package:skylight_wallet/screens/history.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/platform.dart';
import 'package:skylight_wallet/util/qr_brightness.dart';
import 'package:skylight_wallet/util/secure_clipboard.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart'
    show AddressLabelModel, CryptoWallet, RotatingAddressKind, UsedReceiveAddress;

/// Which used subaddress `/receive_address` shows.
class ReceiveAddressArgs {
  const ReceiveAddressArgs({required this.used});

  /// As the Labeled tab last loaded it; the screen reloads its totals when the
  /// history moves.
  final UsedReceiveAddress used;
}

/// How [wallet]'s used addresses are written in the shared widgets.
LabeledAddressCoin labeledAddressCoinOf(CryptoWallet wallet) => (
  coinSymbol: wallet.coinSymbol,
  baseUnitDecimals: wallet.baseUnitDecimals,
  kind: wallet.rotatingAddressKind ?? RotatingAddressKind.subaddress,
);

/// Opens the label sheet for [entry] and saves what it returns: a blank label
/// removes it.
Future<void> editAddressLabel(
  BuildContext context,
  CryptoWallet wallet,
  LabeledAddress entry,
) async {
  final i18n = AppLocalizations.of(context)!;
  final labels = context.read<AddressLabelModel>();
  final label = await showAddressLabelSheet(
    context: context,
    strings: i18n.shared,
    coin: labeledAddressCoinOf(wallet),
    used: entry.used,
    initialLabel: entry.label,
  );
  if (label == null) return;
  await labels.setLabel(wallet.coinSymbol, entry.used.address, label);
}

/// One used subaddress: its QR, to hand it out again, what it received, and
/// the way to its transactions (History, filtered to it) and its label.
class ReceiveAddressScreen extends StatefulWidget {
  const ReceiveAddressScreen({super.key});

  @override
  State<ReceiveAddressScreen> createState() => _ReceiveAddressScreenState();
}

class _ReceiveAddressScreenState extends State<ReceiveAddressScreen> with QrBrightness {
  UsedReceiveAddress? _used;
  int? _revision;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (_used == null && args is ReceiveAddressArgs) _used = args.used;
  }

  /// Reloads the totals when the history has moved since they were read.
  void _refresh(CryptoWallet wallet) {
    final revision = wallet.txHistoryRevision;
    final current = _used;
    if (current == null || _revision == revision) return;
    _revision = revision;
    wallet.loadUsedReceiveAddresses().then((all) {
      if (!mounted) return;
      for (final u in all) {
        if (u.address == current.address) {
          setState(() => _used = u);
          return;
        }
      }
    });
  }

  void _copy(String address) {
    final i18n = AppLocalizations.of(context)!;
    SecureClipboard.copy(address);
    showCopyToast(context, i18n.shared.addressCopied);
  }

  /// As Receive's share: anchored for the iOS popover, failures shown.
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

  void _transactions(String address) =>
      Navigator.pushNamed(context, '/history', arguments: HistoryScreenArgs(address: address));

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    // Watched so the totals follow new transactions.
    appWalletOf(context, listen: true);
    final labels = context.watch<AddressLabelModel>();
    final wallet = xmrWallet(context);
    final used = _used;
    if (wallet == null || used == null) {
      return const SizedBox.shrink();
    }
    _refresh(wallet);
    final coin = labeledAddressCoinOf(wallet);
    final label = labels.labelFor(wallet.coinSymbol, used.address);
    final entry = (used: used, label: label);
    final title = label ?? labeledAddressName(i18n.shared, coin.kind, used.index);

    AddressDetailContent content({required double viewportHeight, bool wide = false}) =>
        AddressDetailContent(
          strings: i18n.shared,
          coin: coin,
          entry: entry,
          onCopy: () => _copy(used.address),
          onTransactions: () => _transactions(used.address),
          onEditLabel: () => editAddressLabel(context, wallet, entry),
          viewportHeight: viewportHeight,
          qrEnlarged: qrEnlarged,
          onToggleQr: !wide && QrBrightness.canBrighten ? toggleQr : null,
          wide: wide,
        );

    if (isDesktop) {
      return DesktopShell(
        active: DesktopNav.home,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(44, 30, 44, 36),
          children: [
            DesktopBackLink(
              label: i18n.shared.receiveTitle,
              onTap: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),
            Text(title, style: desktopTitleStyle),
            const SizedBox(height: 24),
            content(viewportHeight: double.infinity, wide: true),
          ],
        ),
      );
    }

    return AddressDetailView(
      title: title,
      onBack: () => Navigator.of(context).pop(),
      onShare: QrBrightness.canBrighten ? (origin) => _share(used.address, origin) : null,
      body: (viewportHeight) => content(viewportHeight: viewportHeight),
    );
  }
}
