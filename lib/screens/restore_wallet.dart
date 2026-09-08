import 'package:bip39/bip39.dart' as bip39;
// ignore: implementation_imports — the BIP39 English wordlist for per-word checks.
import 'package:bip39/src/wordlists/english.dart' show WORDLIST;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/util/secure_screen.dart';
import 'package:spice_wallet/widgets/seed_grid.dart' show seedGridColumns;
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

class RestoreWalletScreen extends StatefulWidget {
  const RestoreWalletScreen({super.key});

  @override
  State<RestoreWalletScreen> createState() => _RestoreWalletScreenState();
}

class _RestoreWalletScreenState extends State<RestoreWalletScreen> with SecureScreenMixin {
  static const _lengths = [12, 15, 18, 21, 24];
  static final Set<String> _wordSet = WORDLIST.toSet();

  static const _maxWords = 24;
  int _count = 15;
  // Allocated up front (max length) so changing length never disposes/creates
  // controllers mid-tree; slots past _count just aren't shown.
  late final List<TextEditingController> _controllers = List.generate(
    _maxWords,
    (_) => TextEditingController(),
  );
  late final List<FocusNode> _nodes = List.generate(_maxWords, (_) => FocusNode());
  DateTime? _restoreDate; // null once chosen = "I'm not sure" (scan from genesis)
  bool _scanChosen = false;
  bool _isLoading = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  List<String> _readWords() => [
    for (var i = 0; i < _count; i++) _controllers[i].text.trim().toLowerCase(),
  ];

  bool _valid(String w) => _wordSet.contains(w);

  /// First left-behind (unfocused) word that isn't in the wordlist.
  int? _firstBad(List<String> words) {
    for (var i = 0; i < _count; i++) {
      if (words[i].isNotEmpty && !_valid(words[i]) && !_nodes[i].hasFocus) return i;
    }
    return null;
  }

  /// Runs the SHA-256 checksum only once every slot already holds a valid word.
  bool _checksumOk(List<String> words) =>
      words.every((w) => w.isNotEmpty && _valid(w)) && bip39.validateMnemonic(words.join(' '));

  void _setCount(int n) {
    if (n != _count) setState(() => _count = n);
  }

  /// Splits pasted/space-separated input across the slots from [i] onward.
  void _onSlotChanged(int i, String value) {
    if (RegExp(r'\s').hasMatch(value)) {
      final tokens = value.trim().split(RegExp(r'\s+'));
      for (var k = 0; k < tokens.length && i + k < _count; k++) {
        _controllers[i + k].text = tokens[k];
      }
      final next = (i + tokens.length).clamp(0, _count - 1);
      _nodes[next].requestFocus();
      _controllers[next].selection = TextSelection.collapsed(
        offset: _controllers[next].text.length,
      );
    }
    // No setState — the changed controllers notify the slot + footer listeners.
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    final tokens = text.split(RegExp(r'\s+'));
    if (_lengths.contains(tokens.length)) _setCount(tokens.length);
    for (var i = 0; i < _count; i++) {
      _controllers[i].text = i < tokens.length ? tokens[i] : '';
    }
  }

  Widget _buildSlot(int i) {
    return _WordSlot(
      key: ValueKey(i),
      index: i + 1,
      controller: _controllers[i],
      focusNode: _nodes[i],
      validate: _valid,
      isLast: i == _count - 1,
      onChanged: (v) => _onSlotChanged(i, v),
      onSubmitted: () {
        if (i + 1 < _count) _nodes[i + 1].requestFocus();
      },
    );
  }

  Future<void> _openScanFrom() async {
    final result = await showModalBottomSheet<({DateTime? date})>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ScanFromSheet(initial: _restoreDate, chosen: _scanChosen),
    );
    if (result != null) {
      setState(() {
        _restoreDate = result.date;
        _scanChosen = true;
      });
    }
  }

  Future<void> _restore() async {
    if (_isLoading) return;
    final mnemonic = _readWords().join(' ');
    if (!bip39.validateMnemonic(mnemonic)) return;

    final i18n = AppLocalizations.of(context)!;
    final manager = Provider.of<WalletManager>(context, listen: false);
    setState(() => _isLoading = true);

    try {
      await manager.restoreAll(
        seed: Bip39Seed(mnemonic),
        from: RestorePoint.date(_restoreDate ?? DateTime(2014, 4, 18)),
      );
    } catch (error) {
      log(LogLevel.error, error.toString());
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.unknownError)));
      }
      return;
    }

    manager.syncInBackground();
    if (mounted) {
      Provider.of<FiatRateModel>(context, listen: false).startService(walletManager: manager);
      Navigator.pushNamedAndRemoveUntil(context, '/wallet_home', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final cols = seedGridColumns(context);

    // The slots, the notice, and the Restore button react to typing via their
    // own listeners — a keystroke never rebuilds the whole screen (the lag).
    final reactive = Listenable.merge([
      for (var i = 0; i < _count; i++) _controllers[i],
      for (var i = 0; i < _count; i++) _nodes[i],
    ]);

    final String scanValue;
    final TextStyle scanStyle;
    if (!_scanChosen) {
      scanValue = i18n.restoreWalletNotSet;
      scanStyle = BrandText.body.copyWith(color: BrandColors.inkFaint);
    } else if (_restoreDate != null) {
      scanValue = DateFormat.yMMM(Localizations.localeOf(context).toString()).format(_restoreDate!);
      scanStyle = BrandText.amount;
    } else {
      scanValue = i18n.restoreScanFromStart;
      scanStyle = BrandText.body;
    }

    return Scaffold(
      backgroundColor: BrandColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BrandSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: BrandSpacing.sm),
              BrandScreenHeader(
                onBack: () => Navigator.maybePop(context),
                center: Text(i18n.restoreWalletTitle, style: BrandText.appBar),
                action: _PasteChip(label: i18n.restoreWalletPaste, onTap: _paste),
              ),
              const SizedBox(height: BrandSpacing.lg),
              Row(
                children: [
                  SectionHeader(label: i18n.restoreWalletSeedLength, padding: EdgeInsets.zero),
                  const Spacer(),
                  _SeedLengthSelector(lengths: _lengths, selected: _count, onSelect: _setCount),
                ],
              ),
              const SizedBox(height: BrandSpacing.md),
              Text(i18n.restoreWalletSubtitle, style: BrandText.bodyMuted),
              const SizedBox(height: BrandSpacing.lg),
              Expanded(
                child: ListView(
                  children: [
                    // Rows sized to their content (not a fixed grid aspect
                    // ratio); 3 columns, or 2 on narrow screens. A short last row
                    // is padded with empty slots.
                    for (var r = 0; r * cols < _count; r++) ...[
                      if (r > 0) const SizedBox(height: 9),
                      Row(
                        children: [
                          for (var c = 0; c < cols && r * cols + c < _count; c++) ...[
                            if (c > 0) const SizedBox(width: 9),
                            Expanded(child: _buildSlot(r * cols + c)),
                          ],
                        ],
                      ),
                    ],
                    ListenableBuilder(
                      listenable: reactive,
                      builder: (context, _) {
                        final words = _readWords();
                        final bad = _firstBad(words);
                        final Widget notice;
                        if (bad != null) {
                          notice = _BadWordNotice(
                            message: i18n.restoreWalletBadWord(bad + 1),
                            suggestion: _suggest(words[bad]),
                            suggestionText: (s) => i18n.restoreWalletDidYouMean(s),
                          );
                        } else if (words.every((w) => w.isNotEmpty && _valid(w)) &&
                            !bip39.validateMnemonic(words.join(' '))) {
                          notice = _BadWordNotice(
                            message: i18n.restoreWalletChecksumError,
                            suggestion: null,
                            suggestionText: (_) => '',
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: BrandSpacing.md),
                          child: notice,
                        );
                      },
                    ),
                    const SizedBox(height: BrandSpacing.lg),
                    _ScanFromCard(
                      label: i18n.restoreWalletScanFrom,
                      reason: i18n.restoreWalletScanFromReason,
                      value: scanValue,
                      valueStyle: scanStyle,
                      onTap: _openScanFrom,
                    ),
                  ],
                ),
              ),
              // Keep the Restore button off the Scan-from card when the words
              // make the list scroll (small screens / 2-column layout).
              const SizedBox(height: BrandSpacing.md),
              ListenableBuilder(
                listenable: reactive,
                builder: (context, _) {
                  final canRestore = !_isLoading && _scanChosen && _checksumOk(_readWords());
                  return BrandButton(
                    label: i18n.restoreWalletRestoreButton,
                    loading: _isLoading,
                    onPressed: canRestore ? _restore : null,
                  );
                },
              ),
              const SizedBox(height: BrandSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  String? _suggestWord;
  String? _suggestResult;

  /// Closest wordlist word within edit distance 2, for the "did you mean" hint.
  /// Cached so it doesn't rescan 2048 words unless the input changed.
  String? _suggest(String word) {
    if (word == _suggestWord) return _suggestResult;
    _suggestWord = word;
    _suggestResult = _computeSuggest(word);
    return _suggestResult;
  }

  String? _computeSuggest(String word) {
    if (word.isEmpty) return null;
    String? best;
    var bestDist = 3;
    for (final w in WORDLIST) {
      if ((w.length - word.length).abs() >= bestDist) continue;
      final d = _levenshtein(word, w);
      if (d < bestDist) {
        bestDist = d;
        best = w;
      }
    }
    return best;
  }

  int _levenshtein(String a, String b) {
    final prev = List<int>.generate(b.length + 1, (i) => i);
    final cur = List<int>.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      cur[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        cur[j + 1] = [cur[j] + 1, prev[j + 1] + 1, prev[j] + cost].reduce((x, y) => x < y ? x : y);
      }
      for (var j = 0; j <= b.length; j++) {
        prev[j] = cur[j];
      }
    }
    return prev[b.length];
  }
}

/// Self-managing slot: it listens to its own controller/focus and rebuilds only
/// itself, so typing in one slot never rebuilds the others.
class _WordSlot extends StatefulWidget {
  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool Function(String) validate;
  final bool isLast;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  const _WordSlot({
    super.key,
    required this.index,
    required this.controller,
    required this.focusNode,
    required this.validate,
    required this.isLast,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  State<_WordSlot> createState() => _WordSlotState();
}

class _WordSlotState extends State<_WordSlot> {
  bool _filled = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _apply(_derive());
    widget.controller.addListener(_onChange);
    widget.focusNode.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    widget.focusNode.removeListener(_onChange);
    super.dispose();
  }

  // A word is flagged red only when its slot is not focused (typed or pasted,
  // then left) — never while it's being edited.
  (bool, bool) _derive() {
    final w = widget.controller.text.trim().toLowerCase();
    final filled = w.isNotEmpty;
    return (filled, filled && !widget.focusNode.hasFocus && !widget.validate(w));
  }

  void _apply((bool, bool) v) {
    _filled = v.$1;
    _error = v.$2;
  }

  void _onChange() {
    final v = _derive();
    if (v.$1 != _filled || v.$2 != _error) setState(() => _apply(v));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // The field box is text-tight; make the whole slot (incl. padding) focus it.
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.focusNode.requestFocus(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: _filled ? BrandColors.card : BrandColors.surfaceSunken,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _error ? BrandColors.error : BrandColors.border, width: 1),
        ),
        child: Row(
          // Bottom-align so the smaller number sits on the word's baseline.
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                widget.index.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontFamily: 'Ubuntu Mono',
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.inkDisabled,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                onChanged: widget.onChanged,
                onSubmitted: (_) => widget.onSubmitted(),
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: widget.isLast ? TextInputAction.done : TextInputAction.next,
                cursorColor: BrandColors.cinnamon,
                // Force the field box down to the text height so it doesn't add
                // vertical padding (which made the slot tall + misaligned the no.).
                strutStyle: const StrutStyle(forceStrutHeight: true, height: 1, fontSize: 13.5),
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  color: _error ? BrandColors.error : BrandColors.ink,
                ),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented control for the seed length — a tinted track with the selected
/// number lifted onto a white pill.
class _SeedLengthSelector extends StatelessWidget {
  final List<int> lengths;
  final int selected;
  final ValueChanged<int> onSelect;

  const _SeedLengthSelector({
    required this.lengths,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: BrandColors.surfaceAccent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [
          for (final n in lengths)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(n),
              child: AnimatedContainer(
                duration: BrandMotion.transition,
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: n == selected ? BrandColors.paper : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '$n',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: n == selected ? BrandColors.ink : BrandColors.inkMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PasteChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PasteChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: BrandColors.cinnamon),
        ),
      ),
    );
  }
}

class _BadWordNotice extends StatelessWidget {
  final String message;
  final String? suggestion;
  final String Function(String) suggestionText;

  const _BadWordNotice({
    required this.message,
    required this.suggestion,
    required this.suggestionText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 16, color: BrandColors.error),
        const SizedBox(width: BrandSpacing.sm),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: BrandText.caption.copyWith(color: BrandColors.error),
              children: [
                TextSpan(text: message),
                if (suggestion != null)
                  TextSpan(
                    text: ' ${suggestionText(suggestion!)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet for the restore height — pick a month/year, or "I'm not sure"
/// (scan from genesis). Returns `(date: DateTime?)` on Done, null if dismissed.
///
/// [initial] and [chosen] together carry the current selection back in: a null
/// [initial] means "I'm not sure" once [chosen], and "nothing picked yet"
/// before that — so both are needed to reopen on the right option.
class _ScanFromSheet extends StatefulWidget {
  final DateTime? initial;
  final bool chosen;
  const _ScanFromSheet({required this.initial, required this.chosen});

  @override
  State<_ScanFromSheet> createState() => _ScanFromSheetState();
}

class _ScanFromSheetState extends State<_ScanFromSheet> {
  late bool _pickMonth;
  late int _month;
  late int _year;

  @override
  void initState() {
    super.initState();
    _pickMonth = !(widget.chosen && widget.initial == null);
    final d = widget.initial ?? DateTime.now();
    _month = d.month;
    _year = d.year;
  }

  void _done() {
    Navigator.pop(context, (date: _pickMonth ? DateTime(_year, _month) : null));
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: BrandColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            BrandSpacing.xl,
            BrandSpacing.md,
            BrandSpacing.xl,
            BrandSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 5,
                  decoration: BoxDecoration(
                    color: BrandColors.borderStrong,
                    borderRadius: BrandRadii.rPill,
                  ),
                ),
              ),
              const SizedBox(height: BrandSpacing.lg),
              Text(i18n.restoreScanTitle, style: BrandText.sheetTitle),
              const SizedBox(height: BrandSpacing.sm),
              Text(i18n.restoreScanDescription, style: BrandText.bodyMuted),
              const SizedBox(height: BrandSpacing.lg),
              _SheetOption(
                selected: _pickMonth,
                title: i18n.restoreScanPickMonth,
                onTap: () => setState(() => _pickMonth = true),
                expanded: Row(
                  children: [
                    Expanded(
                      child: _ScanDropdown<int>(
                        value: _month,
                        items: [for (var m = 1; m <= 12; m++) m],
                        label: (m) => DateFormat.MMMM(locale).format(DateTime(2000, m)),
                        onChanged: (m) => setState(() => _month = m),
                      ),
                    ),
                    const SizedBox(width: BrandSpacing.sm),
                    Expanded(
                      child: _ScanDropdown<int>(
                        value: _year,
                        items: [for (var y = now.year; y >= 2014; y--) y],
                        label: (y) => '$y',
                        onChanged: (y) => setState(() => _year = y),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: BrandSpacing.md),
              _SheetOption(
                selected: !_pickMonth,
                title: i18n.restoreScanNotSure,
                description: i18n.restoreScanNotSureDesc,
                onTap: () => setState(() => _pickMonth = false),
              ),
              const SizedBox(height: BrandSpacing.lg),
              BrandButton(label: i18n.restoreScanDone, onPressed: _done),
            ],
          ),
        ),
      ),
    );
  }
}

/// A radio card in the scan-from sheet (radio on the left), expanding when
/// selected.
class _SheetOption extends StatelessWidget {
  final bool selected;
  final String title;
  final String? description;
  final Widget? expanded;
  final VoidCallback onTap;

  const _SheetOption({
    required this.selected,
    required this.title,
    this.description,
    this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: BrandMotion.transition,
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? BrandColors.card : BrandColors.surfaceSunken,
          borderRadius: BrandRadii.rField,
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BrandRadii.rField,
          border: Border.all(
            color: selected ? BrandColors.cinnamon : BrandColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RadioDot(selected: selected),
                const SizedBox(width: BrandSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: BrandText.listTitle),
                      if (description != null) ...[
                        const SizedBox(height: 2),
                        Text(description!, style: BrandText.caption),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (selected && expanded != null) ...[const SizedBox(height: 12), expanded!],
          ],
        ),
      ),
    );
  }
}

/// Tinted select used inside the scan-from sheet.
class _ScanDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  const _ScanDropdown({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: BrandColors.surfaceSunken,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrandColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: BrandColors.inkFaint),
          borderRadius: BrandRadii.rField,
          dropdownColor: BrandColors.card,
          style: TextStyle(fontFamily: 'Ubuntu', fontSize: 14, color: BrandColors.ink),
          items: [for (final it in items) DropdownMenuItem<T>(value: it, child: Text(label(it)))],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _ScanFromCard extends StatelessWidget {
  final String label;
  final String reason;
  final String value;
  final TextStyle valueStyle;
  final VoidCallback onTap;

  const _ScanFromCard({
    required this.label,
    required this.reason,
    required this.value,
    required this.valueStyle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const radius = BrandRadii.rField;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BrandColors.surfaceSunken,
        borderRadius: radius,
        border: Border.all(color: BrandColors.border),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 15),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: BrandText.listTitle),
                        const SizedBox(height: 2),
                        Text(reason, style: BrandText.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: BrandSpacing.md),
                  Text(value, style: valueStyle),
                  const SizedBox(width: BrandSpacing.xs),
                  Icon(Icons.chevron_right, size: 18, color: BrandColors.inkFaint),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
