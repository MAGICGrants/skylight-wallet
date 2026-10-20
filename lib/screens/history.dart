import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/consts.dart' as consts;
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/screens/desktop/home_shell.dart';
import 'package:skylight_wallet/util/platform.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';
import 'package:skylight_wallet/widgets/wallet_navigation_bar.dart';
import 'package:wallet_domain/wallet_domain.dart' show CryptoWallet, TxDetails;
import 'package:wallet_infra/wallet_infra.dart' show LogLevel, exportFileName, log, saveExportFile;

/// The wallet's transactions, filterable by direction and by address, and
/// exportable as CSV (the filtered ones, or all of them with no filter). A
/// top-level destination in the navigation bar, as in Spice; Skylight holds
/// only Monero, so Spice's blockchain and asset filters have no place here.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

enum _Filter { type, address }

/// Whether [tx] involves [address]: received at it, or sent to it.
///
/// One list serves both directions: on an incoming transaction `recipients`
/// holds the wallet's own addresses it was received at, and on an outgoing one
/// who was paid. Change is included deliberately: a spend that returned change
/// to the address did involve it. Monero addresses are compared exactly; base58
/// is case-significant.
@visibleForTesting
bool txInvolvesAddress(TxDetails tx, String address) {
  final wanted = address.trim();
  return tx.recipients.any((r) => r.address.trim() == wanted);
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Unchecked (hidden) directions; empty = everything checked (the default).
  final Set<int> _typesHidden = {};

  /// The one address the address filter matches, or null for no filter.
  String? _address;

  /// The last paste or scan was not a Monero address. Cleared by the next
  /// attempt or a reset.
  bool _addressInvalid = false;

  _Filter? _open;

  void _toggleOpen(_Filter f) => setState(() => _open = _open == f ? null : f);

  /// A bare address or a `monero:<address>?...` URI; null if neither.
  String? _extractAddress(String raw, CryptoWallet wallet) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri != null && uri.scheme.toLowerCase() == 'monero') {
      return wallet.isAddressValid(uri.path) ? uri.path : null;
    }
    return wallet.isAddressValid(value) ? value : null;
  }

  void _setAddress(String? raw, CryptoWallet wallet) {
    final found = raw == null ? null : _extractAddress(raw, wallet);
    setState(() {
      if (found == null) {
        _addressInvalid = true;
        return;
      }
      _address = found;
      _addressInvalid = false;
    });
  }

  Future<void> _pasteAddress(CryptoWallet wallet) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (mounted) _setAddress(data?.text, wallet);
  }

  Future<void> _scanAddress(CryptoWallet wallet) async {
    final result = await Navigator.pushNamed(context, '/scan_qr');
    if (mounted && result is String) _setAddress(result, wallet);
  }

  void _clearAddress() => setState(() {
    _address = null;
    _addressInvalid = false;
  });

  /// Saves [txs], the transactions the filters let through, as CSV. [anchor]
  /// is the button, for the iPad share popover.
  Future<void> _export(CryptoWallet asset, List<TxDetails> txs, BuildContext anchor) async {
    final i18n = AppLocalizations.of(context)!;
    final box = anchor.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    try {
      final saved = await saveExportFile(
        name: exportFileName('skylight-history', 'csv', DateTime.now()),
        bytes: utf8.encode(txHistoryCsv([for (final tx in txs) (tx: tx, asset: asset)])),
        typeLabel: 'CSV',
        extension: 'csv',
        mimeType: 'text/csv',
        sharePositionOrigin: origin,
      );
      if (saved && mounted) showBrandToast(context, i18n.historyExported);
    } catch (e) {
      log(LogLevel.error, '[History] CSV export failed: $e');
      if (mounted) showBrandToast(context, i18n.historyExportFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    // Watched so the list follows new transactions; the rows read the engine
    // wallet's exact amounts.
    appWalletOf(context, listen: true);
    final fiatRate = context.watch<FiatRateModel>();
    final asset = xmrWallet(context);
    // Content gutter: the desktop shell caps width and wants wider margins.
    final gutter = isDesktop ? 44.0 : 20.0;

    final all = asset?.txHistory ?? const <TxDetails>[];
    final entries = all.where((tx) {
      if (_typesHidden.contains(tx.direction)) return false;
      final address = _address;
      if (address != null && !txInvolvesAddress(tx, address)) return false;
      return true;
    }).toList();

    int typeCount(int type) => all.where((tx) => tx.direction == type).length;
    final typeOptions = [
      _Option(
        '${consts.txDirectionIncoming}',
        i18n.coinHomeReceived,
        _typeIcon(Icons.south, BrandColors.success, BrandColors.successBg),
        typeCount(consts.txDirectionIncoming),
      ),
      _Option(
        '${consts.txDirectionOutgoing}',
        i18n.coinHomeSent,
        _typeIcon(Icons.north, BrandColors.primary, BrandColors.surfaceAccent),
        typeCount(consts.txDirectionOutgoing),
      ),
    ];
    // The pill shows the number of checked options, but only once some are
    // unchecked: all checked is the default and reads as "no filter".
    final typesChecked = typeOptions.where((o) => !_typesHidden.contains(int.parse(o.value)));
    final typeCountBadge = typesChecked.length == typeOptions.length ? null : typesChecked.length;

    final list = entries.isEmpty || asset == null
        ? Center(child: Text(i18n.homeNoTransactions, style: BrandText.bodyMuted))
        : _Timeline(
            entries: entries,
            asset: asset,
            i18n: i18n,
            fiatRate: fiatRate,
            gutter: gutter,
            onTapTx: (tx) => showTxDetailsDialog(context, tx),
          );

    final canExport = asset != null && entries.isNotEmpty;
    void export(BuildContext anchor) {
      if (canExport) _export(asset, entries, anchor);
    }

    final filters = <Widget>[
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
        child: Row(
          children: [
            _FilterPill(
              label: i18n.historyFilterType,
              count: typeCountBadge,
              open: _open == _Filter.type,
              onTap: () => _toggleOpen(_Filter.type),
            ),
            const SizedBox(width: 7),
            _FilterPill(
              label: i18n.historyFilterAddress,
              count: _address == null ? null : 1,
              open: _open == _Filter.address,
              onTap: () => _toggleOpen(_Filter.address),
            ),
          ],
        ),
      ),
      if (_open == _Filter.type)
        _FilterPanel(
          header: i18n.historyFilterType,
          options: typeOptions,
          isSelected: (v) => !_typesHidden.contains(int.parse(v)),
          gutter: gutter,
          onToggle: (v) => setState(() => _typesHidden.toggle(int.parse(v))),
          onReset: () => setState(_typesHidden.clear),
          onDone: () => setState(() => _open = null),
        ),
      if (_open == _Filter.address && asset != null)
        _AddressPanel(
          address: _address,
          iconAsset: asset.iconAsset,
          invalid: _addressInvalid,
          gutter: gutter,
          onPaste: () => _pasteAddress(asset),
          onScan: () => _scanAddress(asset),
          onClear: _clearAddress,
          onDone: () => setState(() => _open = null),
        ),
      Expanded(
        child: _open == null
            ? list
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _open = null),
                child: Opacity(opacity: 0.4, child: IgnorePointer(child: list)),
              ),
      ),
    ];

    if (isDesktop) {
      return DesktopShell(
        active: DesktopNav.history,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(44, 30, 44, 20),
              child: Row(
                children: [
                  Expanded(child: Text(i18n.historyTitle, style: desktopTitleStyle)),
                  Builder(
                    builder: (anchor) => BrandButton.secondary(
                      label: i18n.historyExportCsv,
                      icon: Icons.file_download_outlined,
                      expand: false,
                      onPressed: canExport ? () => export(anchor) : null,
                    ),
                  ),
                ],
              ),
            ),
            ...filters,
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: BrandColors.paper,
      bottomNavigationBar: const WalletNavigationBar(selectedIndex: 1),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: BrandScreenHeader(
                    center: Text(i18n.historyTitle, style: BrandText.appBar.copyWith(fontSize: 16)),
                    action: Tooltip(
                      message: i18n.historyExportCsv,
                      child: Opacity(
                        opacity: canExport ? 1 : 0.4,
                        child: Builder(
                          builder: (anchor) => IconCircleButton(
                            icon: Icons.file_download_outlined,
                            onPressed: canExport ? () => export(anchor) : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...filters,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeIcon(IconData icon, Color fg, Color bg) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 13, color: fg),
    );
  }
}

extension _ToggleSet<T> on Set<T> {
  void toggle(T value) => contains(value) ? remove(value) : add(value);
}

/// A filter option: its stored value, display name, leading icon, and how many
/// transactions match it overall.
class _Option {
  final String value;
  final String label;
  final Widget icon;
  final int count;
  const _Option(this.value, this.label, this.icon, this.count);
}

class _Timeline extends StatelessWidget {
  final List<TxDetails> entries;
  final CryptoWallet asset;
  final AppLocalizations i18n;
  final FiatRateModel fiatRate;
  final double gutter;
  final void Function(TxDetails tx) onTapTx;

  const _Timeline({
    required this.entries,
    required this.asset,
    required this.i18n,
    required this.fiatRate,
    required this.gutter,
    required this.onTapTx,
  });

  @override
  Widget build(BuildContext context) {
    final rows = withDayHeaders(entries, (tx) => tx.timestamp);

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 24),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is String) {
          return Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 18, bottom: 4),
            child: SectionHeader(label: row, padding: EdgeInsets.zero),
          );
        }
        final tx = row as TxDetails;
        final next = index + 1 < rows.length ? rows[index + 1] : null;
        // No coin icon, as on the home screen: Skylight is single-coin.
        return TxActivityRow(
          tx: tx,
          asset: asset,
          showCoinIcon: false,
          labels: TxActivityLabels(received: i18n.coinHomeReceived, sent: i18n.coinHomeSent),
          fiatRate: fiatRate,
          showDivider: next is TxDetails,
          onTap: () => onTapTx(tx),
        );
      },
    );
  }
}

/// The address filter's panel: one Monero address, set by paste or scan.
///
/// Same chrome as [_FilterPanel] (card, shadow, sunken footer) over the
/// address book's entry row, so setting an address here looks like setting
/// one on a contact.
class _AddressPanel extends StatelessWidget {
  final String? address;
  final String iconAsset;
  final bool invalid;
  final double gutter;
  final VoidCallback onPaste;
  final VoidCallback onScan;
  final VoidCallback onClear;
  final VoidCallback onDone;

  const _AddressPanel({
    required this.address,
    required this.iconAsset,
    required this.invalid,
    required this.gutter,
    required this.onPaste,
    required this.onScan,
    required this.onClear,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: _panelDecoration,
        foregroundDecoration: _panelBorder,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: SectionHeader(label: i18n.historyFilterAddress, padding: EdgeInsets.zero),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: Text(i18n.historyFilterAddressHint, style: BrandText.caption),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: address == null ? _empty(i18n) : _filled(),
            ),
            _PanelFooter(onReset: onClear, onDone: onDone),
          ],
        ),
      ),
    );
  }

  Widget _empty(AppLocalizations i18n) => Container(
    decoration: BoxDecoration(
      color: BrandColors.surfaceSunken,
      border: Border.all(color: invalid ? BrandColors.error : BrandColors.border),
      borderRadius: BorderRadius.circular(14),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: BrandColors.surfaceTinted, shape: BoxShape.circle),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 15,
                color: BrandColors.inkFaint,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                i18n.historyFilterAddressAny,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: BrandColors.inkFaint,
                ),
              ),
            ),
            MiniActionButton(
              bordered: true,
              icon: Icons.content_paste_outlined,
              label: i18n.sendPasteButton,
              onTap: onPaste,
            ),
            if (Platform.isAndroid || Platform.isIOS) ...[
              const SizedBox(width: 7),
              MiniActionButton(
                bordered: true,
                icon: Icons.qr_code_scanner,
                label: i18n.sendScanButton,
                onTap: onScan,
              ),
            ],
          ],
        ),
        if (invalid) ...[
          const SizedBox(height: 8),
          Text(
            i18n.historyFilterAddressInvalid,
            style: BrandText.caption.copyWith(color: BrandColors.error),
          ),
        ],
      ],
    ),
  );

  Widget _filled() => BrandCard(
    radius: 14,
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    child: Row(
      children: [
        CoinMark(coinSymbol: 'XMR', iconAsset: iconAsset, size: 30),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monero',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: BrandColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                shortenMiddle(address!, head: 9, tail: 9),
                style: TextStyle(
                  fontFamily: 'Ubuntu Mono',
                  fontSize: 11,
                  color: BrandColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        Tappable(
          behavior: HitTestBehavior.opaque,
          onTap: onClear,
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: BrandColors.surfaceTinted, shape: BoxShape.circle),
            child: Icon(Icons.close, size: 13, color: BrandColors.inkMuted),
          ),
        ),
      ],
    ),
  );
}

/// A filter panel's card: shadowed, with its border in the foreground so the
/// footer's fill cannot overpaint it (a background border is drawn behind the
/// children, dimming the bottom corners). Getters: the colours follow the
/// theme.
BoxDecoration get _panelDecoration => BoxDecoration(
  color: BrandColors.card,
  borderRadius: BorderRadius.circular(18),
  boxShadow: const [
    BoxShadow(color: Color(0x242C170C), blurRadius: 28, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0F2C170C), blurRadius: 2, offset: Offset(0, 1)),
  ],
);

BoxDecoration get _panelBorder => BoxDecoration(
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: BrandColors.borderStrong),
);

/// A filter panel's Reset / Done footer.
class _PanelFooter extends StatelessWidget {
  final VoidCallback onReset;
  final VoidCallback onDone;

  const _PanelFooter({required this.onReset, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: BrandColors.surfaceSunken,
        border: Border(top: BorderSide(color: BrandColors.surfaceTinted)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Tappable(
            behavior: HitTestBehavior.opaque,
            onTap: onReset,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(
                i18n.historyFilterReset,
                style: TextStyle(fontSize: 13, color: BrandColors.primary),
              ),
            ),
          ),
          BrandButton(label: i18n.done, onPressed: onDone, expand: false, dense: true),
        ],
      ),
    );
  }
}

/// A rounded filter chip: category name, a count badge and an up/down chevron.
/// Goes dark (the design's ink pill) once it is open or has a selection.
class _FilterPill extends StatelessWidget {
  final String label;
  final int? count; // null = every option checked (the default): no badge.
  final bool open;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.count,
    required this.open,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = open || count != null;
    final fg = active ? BrandColors.onPrimary : BrandColors.ink;
    return Tappable(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active ? BrandColors.inverseSurface : BrandColors.card,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: active ? BrandColors.inverseSurface : BrandColors.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 12.5, color: fg)),
            if (count != null) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                decoration: BoxDecoration(
                  color: BrandColors.onPrimary.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: 'Ubuntu Mono',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 7),
            Icon(
              open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 15,
              color: active ? fg : BrandColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// The inline multi-select dropdown for one filter: a card of checkbox rows
/// (icon, name, count) with a Reset / Done footer.
class _FilterPanel extends StatelessWidget {
  final String header;
  final List<_Option> options;
  final bool Function(String value) isSelected;
  final double gutter;
  final ValueChanged<String> onToggle;
  final VoidCallback onReset;
  final VoidCallback onDone;

  const _FilterPanel({
    required this.header,
    required this.options,
    required this.isSelected,
    required this.gutter,
    required this.onToggle,
    required this.onReset,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: _panelDecoration,
        foregroundDecoration: _panelBorder,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: SectionHeader(label: header, padding: EdgeInsets.zero),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (var i = 0; i < options.length; i++)
                    _row(options[i], last: i == options.length - 1),
                ],
              ),
            ),
            _PanelFooter(onReset: onReset, onDone: onDone),
          ],
        ),
      ),
    );
  }

  Widget _row(_Option opt, {required bool last}) {
    final selected = isSelected(opt.value);
    return Tappable(
      behavior: HitTestBehavior.opaque,
      onTap: () => onToggle(opt.value),
      child: Container(
        decoration: last
            ? null
            : BoxDecoration(
                border: Border(bottom: BorderSide(color: BrandColors.surfaceTinted)),
              ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _Check(selected: selected),
            const SizedBox(width: 12),
            opt.icon,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                opt.label,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? BrandColors.ink : BrandColors.inkMuted,
                ),
              ),
            ),
            Text(
              '${opt.count}',
              style: TextStyle(
                fontFamily: 'Ubuntu Mono',
                fontSize: 12,
                color: BrandColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 20×20 rounded checkbox: a filled tick when on.
class _Check extends StatelessWidget {
  final bool selected;
  const _Check({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? BrandColors.primaryDeep : null,
        borderRadius: BorderRadius.circular(6),
        border: selected ? null : Border.all(color: BrandColors.inputBorder, width: 1.5),
      ),
      child: selected ? const Icon(Icons.check, size: 13, color: BrandColors.onPrimary) : null,
    );
  }
}
