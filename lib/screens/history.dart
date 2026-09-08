import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/consts.dart' as consts;
import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/util/coin_assets.dart';
import 'package:spice_wallet/widgets/tx_activity_row.dart';
import 'package:spice_wallet/widgets/tx_details.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:spice_wallet/widgets/wallet_navigation_bar.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// A single, filterable timeline of every transaction across all chains/assets.
/// A top-level destination reachable from the navigation bar.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

enum _Filter { blockchain, asset, type }

class _HistoryScreenState extends State<HistoryScreen> {
  // Unchecked (hidden) values per filter; empty = everything checked (default).
  final Set<String> _chainsHidden = {}; // chain symbols
  final Set<String> _assetsHidden = {}; // asset coin symbols
  final Set<int> _typesHidden = {}; // consts.txDirection*
  _Filter? _open;

  void _toggleOpen(_Filter f) => setState(() => _open = _open == f ? null : f);

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final manager = context.watch<WalletManager>();
    final fiatRate = context.watch<FiatRateModel>();
    final fiatSymbol = consts.currencySymbols[fiatRate.fiatCode] ?? '\$';

    // Merge every asset's history into one newest-first timeline.
    final all = <TxEntry>[
      for (final asset in manager.allWallets)
        for (final tx in asset.txHistory) (tx: tx, asset: asset),
    ]..sort((a, b) => b.tx.timestamp.compareTo(a.tx.timestamp));

    final entries = all.where((e) {
      if (_chainsHidden.contains(chainSymbolOf(e.asset))) return false;
      if (_assetsHidden.contains(e.asset.coinSymbol)) return false;
      if (_typesHidden.contains(e.tx.direction)) return false;
      return true;
    }).toList();

    // Filter options (value / label / icon / total count).
    Widget coinIcon(String sym) =>
        CoinMark(coinSymbol: sym, iconAsset: manager.getWallet(sym)?.iconAsset ?? '', size: 24);
    String coinName(String sym) => manager.getWallet(sym)?.coinName ?? sym;
    String assetChain(String sym) {
      final w = manager.getWallet(sym);
      return w != null ? chainSymbolOf(w) : sym;
    }

    // A blockchain counts as configured once its chain wallet has a connection
    // set up; its tokens (e.g. DAI on Ethereum) share that connection.
    bool chainConfigured(String chainSym) =>
        manager.getWallet(chainSym)?.connectionAddress.isNotEmpty ?? false;

    // List every configured chain (even with no transactions yet), plus any that
    // already has history.
    final chainSymbols = {
      for (final w in manager.allWallets)
        if (chainConfigured(chainSymbolOf(w))) chainSymbolOf(w),
      for (final e in all) chainSymbolOf(e.asset),
    };

    // Assets: every asset on a configured chain, plus any with history — scoped
    // to the checked blockchain(s).
    final assetSymbols = {
      for (final w in manager.allWallets)
        if (chainConfigured(chainSymbolOf(w)) && !_chainsHidden.contains(chainSymbolOf(w)))
          w.coinSymbol,
      for (final e in all)
        if (!_chainsHidden.contains(chainSymbolOf(e.asset))) e.asset.coinSymbol,
    };

    // Every dropdown lists its options by how many transactions match, desc.
    final chainOptions = [
      for (final c in chainSymbols)
        _Option(c, coinName(c), coinIcon(c), all.where((e) => chainSymbolOf(e.asset) == c).length),
    ]..sort((a, b) => b.count.compareTo(a.count));
    final assetOptions = [
      for (final a in assetSymbols)
        _Option(a, coinName(a), coinIcon(a), all.where((e) => e.asset.coinSymbol == a).length),
    ]..sort((a, b) => b.count.compareTo(a.count));
    int typeCount(int type) => all.where((e) => e.tx.direction == type).length;
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
        _typeIcon(Icons.north, BrandColors.cinnamon, BrandColors.surfaceAccent),
        typeCount(consts.txDirectionOutgoing),
      ),
      // Liquidity-pool / swap types (Serai) — no data yet, so these list ahead of
      // the feature and sort last on their zero count.
      _Option(
        '${consts.txTypeBridge}',
        i18n.historyTypeBridge,
        _typeIcon(Icons.compare_arrows, BrandColors.blue, BrandColors.blueBg),
        typeCount(consts.txTypeBridge),
      ),
      _Option(
        '${consts.txTypeSwap}',
        i18n.historyTypeSwap,
        _typeIcon(Icons.swap_horiz, BrandColors.purple, BrandColors.purpleBg),
        typeCount(consts.txTypeSwap),
      ),
      _Option(
        '${consts.txTypeAdd}',
        i18n.historyTypeAdd,
        _typeIcon(Icons.add, BrandColors.success, BrandColors.successBg),
        typeCount(consts.txTypeAdd),
      ),
      _Option(
        '${consts.txTypeRemove}',
        i18n.historyTypeRemove,
        _typeIcon(Icons.remove, BrandColors.cinnamon, BrandColors.surfaceAccent),
        typeCount(consts.txTypeRemove),
      ),
    ]..sort((a, b) => b.count.compareTo(a.count));

    // The pill shows the number of checked options, but only once some are
    // unchecked — all-checked is the default and reads as "no filter".
    int? selectedCount(List<_Option> opts, bool Function(String) hidden) {
      final checked = opts.where((o) => !hidden(o.value)).length;
      return checked == opts.length ? null : checked;
    }

    final list = entries.isEmpty
        ? Center(child: Text(i18n.homeNoTransactions, style: BrandText.bodyMuted))
        : _Timeline(
            entries: entries,
            i18n: i18n,
            fiatRate: fiatRate,
            fiatSymbol: fiatSymbol,
            onTapTx: (asset, tx) => TxDetailsDialog.show(context, asset, tx),
          );

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
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      _FilterPill(
                        label: i18n.historyFilterBlockchain,
                        count: selectedCount(chainOptions, _chainsHidden.contains),
                        open: _open == _Filter.blockchain,
                        onTap: () => _toggleOpen(_Filter.blockchain),
                      ),
                      const SizedBox(width: 7),
                      _FilterPill(
                        label: i18n.historyFilterAsset,
                        count: selectedCount(assetOptions, _assetsHidden.contains),
                        open: _open == _Filter.asset,
                        onTap: () => _toggleOpen(_Filter.asset),
                      ),
                      const SizedBox(width: 7),
                      _FilterPill(
                        label: i18n.historyFilterType,
                        count: selectedCount(typeOptions, (v) => _typesHidden.contains(int.parse(v))),
                        open: _open == _Filter.type,
                        onTap: () => _toggleOpen(_Filter.type),
                      ),
                    ],
                  ),
                ),
                if (_open == _Filter.blockchain)
                  _FilterPanel(
                    header: i18n.historyFilterBlockchain,
                    options: chainOptions,
                    isSelected: (v) => !_chainsHidden.contains(v),
                    onToggle: (v) => setState(() {
                      _chainsHidden.toggle(v);
                      // Re-check assets whose chain just went unchecked, so an
                      // unchecked chain never leaves a stale asset filter behind.
                      _assetsHidden.removeWhere((a) => _chainsHidden.contains(assetChain(a)));
                    }),
                    onReset: () => setState(_chainsHidden.clear),
                    onDone: () => setState(() => _open = null),
                  ),
                if (_open == _Filter.asset)
                  _FilterPanel(
                    header: i18n.historyFilterAsset,
                    options: assetOptions,
                    isSelected: (v) => !_assetsHidden.contains(v),
                    onToggle: (v) => setState(() => _assetsHidden.toggle(v)),
                    onReset: () => setState(_assetsHidden.clear),
                    onDone: () => setState(() => _open = null),
                  ),
                if (_open == _Filter.type)
                  _FilterPanel(
                    header: i18n.historyFilterType,
                    options: typeOptions,
                    isSelected: (v) => !_typesHidden.contains(int.parse(v)),
                    onToggle: (v) => setState(() => _typesHidden.toggle(int.parse(v))),
                    onReset: () => setState(_typesHidden.clear),
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
  final List<TxEntry> entries;
  final AppLocalizations i18n;
  final FiatRateModel fiatRate;
  final String fiatSymbol;
  final void Function(CryptoWallet asset, TxDetails tx) onTapTx;

  const _Timeline({
    required this.entries,
    required this.i18n,
    required this.fiatRate,
    required this.fiatSymbol,
    required this.onTapTx,
  });

  @override
  Widget build(BuildContext context) {
    // Interleave day-header strings between the tx entries.
    final rows = <Object>[];
    DateTime? lastDay;
    for (final e in entries) {
      final d = DateTime.fromMillisecondsSinceEpoch(e.tx.timestamp * 1000);
      final day = DateTime(d.year, d.month, d.day);
      if (day != lastDay) {
        rows.add(DateFormat('d MMMM').format(day).toUpperCase());
        lastDay = day;
      }
      rows.add(e);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is String) {
          return Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 18, bottom: 4),
            child: SectionHeader(label: row, padding: EdgeInsets.zero),
          );
        }
        final e = row as TxEntry;
        final next = index + 1 < rows.length ? rows[index + 1] : null;
        return TxActivityRow(
          tx: e.tx,
          asset: e.asset,
          i18n: i18n,
          fiatRate: fiatRate,
          fiatSymbol: fiatSymbol,
          showDivider: next is TxEntry,
          onTap: () => onTapTx(e.asset, e.tx),
        );
      },
    );
  }
}

/// A rounded filter chip: category name + a count badge + up/down chevron.
/// Goes dark (like the design's ink pill) once it's open or has a selection.
class _FilterPill extends StatelessWidget {
  final String label;
  final int? count; // null = every option checked (default): no badge.
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
    final fg = active ? BrandColors.onCinnamon : BrandColors.ink;
    return GestureDetector(
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
                  color: BrandColors.onCinnamon.withValues(alpha: 0.22),
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
/// (icon + name + count) with a Reset / Done footer.
class _FilterPanel extends StatelessWidget {
  final String header;
  final List<_Option> options;
  final bool Function(String value) isSelected;
  final ValueChanged<String> onToggle;
  final VoidCallback onReset;
  final VoidCallback onDone;

  const _FilterPanel({
    required this.header,
    required this.options,
    required this.isSelected,
    required this.onToggle,
    required this.onReset,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: BrandColors.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x242C170C), blurRadius: 28, offset: Offset(0, 8)),
            BoxShadow(color: Color(0x0F2C170C), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        // Border in the foreground so the footer's fill can't overpaint it (a
        // background border is drawn behind children, dimming the bottom corners).
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: BrandColors.borderStrong),
        ),
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
            Container(
              decoration: BoxDecoration(
                color: BrandColors.surfaceSunken,
                border: Border(top: BorderSide(color: BrandColors.surfaceTinted)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onReset,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Text(
                        i18n.historyFilterReset,
                        style: TextStyle(fontSize: 13, color: BrandColors.cinnamon),
                      ),
                    ),
                  ),
                  BrandButton(label: i18n.done, onPressed: onDone, expand: false, dense: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(_Option opt, {required bool last}) {
    final selected = isSelected(opt.value);
    return GestureDetector(
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

/// The 20×20 rounded checkbox — cinnamon fill + tick when on.
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
        color: selected ? BrandColors.cinnamonDeep : null,
        borderRadius: BorderRadius.circular(6),
        border: selected ? null : Border.all(color: BrandColors.inputBorder, width: 1.5),
      ),
      child: selected ? const Icon(Icons.check, size: 13, color: BrandColors.onCinnamon) : null,
    );
  }
}
