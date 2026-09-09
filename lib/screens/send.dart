import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/consts.dart' as consts;
import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/util/amount_units.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/models/contact_model.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/screens/coin_home.dart';
import 'package:spice_wallet/screens/confirm_send.dart';
import 'package:spice_wallet/util/coin_assets.dart';
import 'package:spice_wallet/util/format.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

class SendScreenArgs {
  final String coinSymbol;
  final String destinationAddress;
  final double? amount;

  /// Set when the address came from a contact (e.g. Send in the address book),
  /// so Send opens showing the contact card rather than a bare address.
  final Contact? contact;

  SendScreenArgs({
    required this.coinSymbol,
    required this.destinationAddress,
    this.amount,
    this.contact,
  });
}

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

final domainRegex = RegExp(r'^(?!-)[A-Za-z0-9-]{1,63}(?<!-)(\.[A-Za-z]{2,})+$');

class _SendScreenState extends State<SendScreen> {
  bool _isLoading = false;
  bool _isLoadingFees = false;
  bool _feesInProgress = false;
  final _destinationAddressController = TextEditingController(text: '');
  final _amountController = TextEditingController(text: '');
  bool _isSweepAll = false;
  Contact? _selectedContact;
  List<PendingTransaction?>? _fees;
  int _selectedPriority = 1; // 0=Low, 1=Normal, 2=High
  int _feeCalculationCounter = 0;
  String _lastFeeFetchKey = '';
  Timer? _feeDebounce;
  // Bumped on every fee-state change so the (separately-routed) priority
  // selector sheet can rebuild live via a ValueListenableBuilder.
  final ValueNotifier<int> _feeRevision = ValueNotifier(0);

  String _destinationAddressError = '';
  String _lastAddressText = ''; // guards against selection-only listener fires
  String _amountError = '';
  int _openAliasResolving = 0; // >0 while OpenAlias resolution is in flight
  bool _formValid = false; // gates the send button
  final FocusNode _addressFocusNode = FocusNode();
  // Caches the last OpenAlias resolution so re-validation (e.g. amount changes)
  // doesn't repeat the network lookup. Output '' = failed/none.
  String _resolveCacheInput = '';
  String _resolveCacheOutput = '';

  String _coinSymbol = 'XMR';
  bool _argsLoaded = false;

  // Anchored "From" asset dropdown.
  final LayerLink _assetMenuLink = LayerLink();
  final OverlayPortalController _assetMenuController = OverlayPortalController();
  bool _assetMenuOpen = false;

  CryptoWallet _wallet(BuildContext context) {
    final manager = Provider.of<WalletManager>(context, listen: false);
    final wallet = manager.getWallet(_coinSymbol);
    if (wallet == null) {
      throw StateError('No wallet for $_coinSymbol');
    }
    return wallet;
  }

  /// Typed amount in integer base units at display precision, or null if the
  /// field isn't a valid number. Avoids handling money as a `double`.
  BigInt? _amountUnits(CryptoWallet wallet) {
    final text = _amountController.text.trim();
    if (text.isEmpty) return BigInt.zero;
    try {
      return decimalToBaseUnits(text, wallet.baseUnitDecimals);
    } catch (_) {
      return null;
    }
  }

  /// Compares the typed amount to the unlocked balance in exact integer base
  /// units, so we never use fragile `double ==`/`>`. Returns <0, 0, >0; or null
  /// when either value is unavailable.
  int? _compareAmountToBalance(CryptoWallet wallet) {
    final balanceUnits = wallet.unlockedBalanceBaseUnits;
    final amountUnits = _amountUnits(wallet);
    if (balanceUnits == null || amountUnits == null) return null;
    return amountUnits.compareTo(balanceUnits);
  }

  Future<String> _resolveAddressIfDomain(String value) async {
    final wallet = _wallet(context);
    if (!domainRegex.hasMatch(value)) return value;
    // All coins use the DNSSEC-over-Tor OpenAlias resolver (Monero included).
    // Empty result → caller shows the resolve error.
    if (wallet.aliasAsset.isNotEmpty) {
      if (value == _resolveCacheInput) return _resolveCacheOutput; // avoid re-lookup
      final i18n = AppLocalizations.of(context)!;
      // Counter (not a bool): resolution runs from several call sites that can
      // overlap (validate, fee calc, send), so the spinner stays up until all
      // finish.
      if (mounted) setState(() => _openAliasResolving++);
      String resolved = '';
      String error = '';
      try {
        resolved = (await wallet.resolveAlias(value))?.address ?? '';
        error = resolved.isEmpty ? i18n.sendOpenAliasResolveError : '';
      } catch (e) {
        log(LogLevel.warn, 'openalias resolve failed: $e', coin: wallet.coinSymbol);
        resolved = '';
        error = i18n.sendOpenAliasResolveError;
      } finally {
        if (mounted) {
          setState(() {
            _openAliasResolving--;
            _destinationAddressError = error;
          });
        }
      }
      _resolveCacheInput = value;
      _resolveCacheOutput = resolved;
      return resolved;
    }
    return value;
  }

  @override
  void initState() {
    super.initState();
    _destinationAddressController.addListener(_onAddressChanged);
    _amountController.addListener(_onAmountChanged);
    _addressFocusNode.addListener(_onAddressFocusChanged);
  }

  @override
  void dispose() {
    _feeDebounce?.cancel();
    _destinationAddressController.removeListener(_onAddressChanged);
    _amountController.removeListener(_onAmountChanged);
    _addressFocusNode.removeListener(_onAddressFocusChanged);
    _addressFocusNode.dispose();
    _destinationAddressController.dispose();
    _amountController.dispose();
    _feeRevision.dispose();
    super.dispose();
  }

  /// Resolve OpenAlias when the address field loses focus (the user finished
  /// typing), rather than on every keystroke.
  void _onAddressFocusChanged() {
    if (!_addressFocusNode.hasFocus) {
      _feeDebounce?.cancel();
      unawaited(() async {
        // Resolve the alias even if the amount isn't filled yet (shows the
        // spinner / address error). Fee calc runs after and reuses the cache.
        await _resolveDestinationAddress();
        await _calculateFeesIfValid();
      }());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    _loadFormFromArgs();
  }

  void _loadFormFromArgs() {
    final args = ModalRoute.of(context)!.settings.arguments as SendScreenArgs?;

    if (args != null) {
      _coinSymbol = args.coinSymbol;
      _destinationAddressController.text = args.destinationAddress;
      _amountController.text = args.amount != null ? args.amount.toString() : '';
      // Same pair the in-send picker sets, so the contact card renders here too.
      _selectedContact = args.contact;
    }
  }

  void _pasteAddressFromClipboard() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || !mounted) return;

    final text = data.text ?? '';
    // Assigning text fires _onAddressChanged, which clears any stale error; then
    // surface the invalid-address warning inline so a bad paste is seen at once
    // rather than only on focus-loss.
    _destinationAddressController.text = text;
    _showInvalidAddressIfNeeded(text);
  }

  /// Sets the inline `Invalid <coin> address` error immediately for a pasted or
  /// scanned value. OpenAlias domains are skipped — they resolve on unfocus.
  void _showInvalidAddressIfNeeded(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final wallet = _wallet(context);
    if (domainRegex.hasMatch(trimmed) && wallet.aliasAsset.isNotEmpty) return;
    if (!wallet.isAddressValid(trimmed)) {
      setState(
        () => _destinationAddressError = AppLocalizations.of(
          context,
        )!.invalidAddressForCoin(wallet.coinName),
      );
    }
  }

  Future<void> _scanQrCode() async {
    final wallet = _wallet(context);

    final result = await Navigator.pushNamed(context, '/scan_qr');

    if (result == null || result is! String) return;

    String address = '';
    double? amount;
    final uri = Uri.tryParse(result);

    if (uri != null && uri.scheme.toLowerCase() == wallet.coinSymbol.toLowerCase()) {
      if (!wallet.isAddressValid(uri.path)) {
        if (mounted) {
          _destinationAddressController.text = uri.path;
          _showInvalidAddressIfNeeded(uri.path);
        }
        return;
      }

      address = uri.path;

      if (uri.queryParameters.containsKey('tx_amount')) {
        amount = double.tryParse(uri.queryParameters['tx_amount']!);
      }
    } else if (wallet.isAddressValid(result)) {
      address = result;
    } else {
      if (mounted) {
        _destinationAddressController.text = result;
        _showInvalidAddressIfNeeded(result);
      }
      return;
    }

    _destinationAddressController.text = address;
    if (amount != null) {
      _amountController.text = amount.toString();
    }
  }

  void _showContactPicker() {
    // Contacts hold one address per blockchain; a token (DAI) uses its chain's.
    final manager = Provider.of<WalletManager>(context, listen: false);
    final chainSymbol = chainSymbolOf(_wallet(context));
    final chain = manager.getWallet(chainSymbol) ?? _wallet(context);
    showBrandSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ContactPickerSheet(
        chain: chain,
        onSelected: (contact) {
          final address = contact.addressFor(chainSymbol);
          if (address == null) return;

          setState(() {
            _selectedContact = contact;
            _destinationAddressController.text = address;
          });
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  void _clearSelectedContact() {
    _destinationAddressController.text = '';

    setState(() {
      _selectedContact = null;
    });
  }

  Future<String> _resolveDestinationAddress() async {
    return _resolveAddressIfDomain(_destinationAddressController.text);
  }

  Future<bool> _validateForm({bool setErrors = true}) async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final unresolvedDestinationAddress = _destinationAddressController.text;
    String destinationAddress = '';

    if (amount == 0) {
      return false;
    }

    final wallet = _wallet(context);
    final i18n = AppLocalizations.of(context)!;

    if (domainRegex.hasMatch(unresolvedDestinationAddress)) {
      destinationAddress = await _resolveAddressIfDomain(unresolvedDestinationAddress);

      if (destinationAddress == '') {
        if (setErrors) {
          setState(() {
            _destinationAddressError = i18n.sendOpenAliasResolveError;
          });
        }
        return false;
      }
    } else if (wallet.isAddressValid(unresolvedDestinationAddress)) {
      destinationAddress = unresolvedDestinationAddress;
    } else {
      if (setErrors) {
        setState(() {
          _destinationAddressError = i18n.invalidAddressForCoin(wallet.coinName);
        });
      }
      return false;
    }

    if (destinationAddress.isEmpty) return false;

    if ((_compareAmountToBalance(wallet) ?? 1) > 0) {
      if (setErrors) {
        setState(() {
          _amountError = i18n.sendInsufficientBalanceError;
        });
      }
      return false;
    }

    return true;
  }

  Future<PendingTransaction?> _createTxForPriority(String destinationAddress, int priority) async {
    final wallet = _wallet(context);
    final amountUnits = _amountUnits(wallet) ?? BigInt.zero;
    final maxRetries = 10;

    for (int i = 0; i < maxRetries; i++) {
      try {
        return await wallet.createTx(
          destinationAddress,
          amountUnits,
          _isSweepAll,
          priority: priority,
        );
      } catch (error) {
        if (error.toString().contains('Unlocked funds too low')) {
          return null;
        }

        if (i == maxRetries - 1) {
          rethrow;
        }
      }
    }

    throw Exception('Failed to create fee priority transaction after $maxRetries retries');
  }

  Future<void> _calculateFees() async {
    final feeFetchKey = '${_destinationAddressController.text}-${_amountController.text}';

    if (feeFetchKey == _lastFeeFetchKey) {
      return;
    }

    _lastFeeFetchKey = feeFetchKey;

    final i18n = AppLocalizations.of(context)!;

    _feeCalculationCounter++;
    final currentRequest = _feeCalculationCounter;

    setState(() {
      _isLoadingFees = true;
      _feesInProgress = true;
      _fees = null;
    });
    _feeRevision.value++;

    final destinationAddress = await _resolveDestinationAddress();

    try {
      final fees = List<PendingTransaction?>.filled(3, null);
      final priorityOrder = [
        _selectedPriority,
        for (var i = 0; i < 3; i++)
          if (i != _selectedPriority) i,
      ];

      for (final idx in priorityOrder) {
        if (currentRequest != _feeCalculationCounter) return;

        await Future<void>.delayed(Duration.zero);

        fees[idx] = await _createTxForPriority(destinationAddress, idx + 1);

        if (currentRequest == _feeCalculationCounter && mounted) {
          setState(() {
            _fees = List.from(fees);
            if (idx == _selectedPriority) {
              _isLoadingFees = false;
            }
          });
          _feeRevision.value++;
        }
      }

      if (currentRequest == _feeCalculationCounter && mounted) {
        setState(() {
          _isLoadingFees = false;
          _feesInProgress = false;

          if (_fees?[_selectedPriority] == null) {
            for (int i = _selectedPriority; i >= 0; i--) {
              if (_fees?[i] != null) {
                _selectedPriority = i;
                break;
              }
            }
          }
        });
        _feeRevision.value++;
      }
    } catch (error) {
      if (currentRequest == _feeCalculationCounter && mounted) {
        setState(() {
          _isLoadingFees = false;
          _feesInProgress = false;
        });
        _feeRevision.value++;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(i18n.sendFailedToGetFeesError)));
      }
    }
  }

  Future<void> _send() async {
    final wallet = _wallet(context);
    final i18n = AppLocalizations.of(context)!;

    setState(() {
      _isLoading = true;
      _destinationAddressError = '';
      _amountError = '';
    });

    final isValid = await _validateForm();

    if (!isValid) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final destinationAddressUnresolved = _destinationAddressController.text;
    final amountUnits = _amountUnits(wallet) ?? BigInt.zero;
    String destinationAddress = '';
    String? destinationOpenAlias;

    if (domainRegex.hasMatch(destinationAddressUnresolved)) {
      destinationAddress = await _resolveAddressIfDomain(destinationAddressUnresolved);
      destinationOpenAlias = destinationAddressUnresolved;
    } else {
      destinationAddress = destinationAddressUnresolved;
    }

    try {
      PendingTransaction tx;

      final currentFeeFetchKey = '${_destinationAddressController.text}-${_amountController.text}';
      final cachedTx = _fees != null && _fees!.length > _selectedPriority
          ? _fees![_selectedPriority]
          : null;

      if (currentFeeFetchKey == _lastFeeFetchKey && cachedTx != null) {
        tx = cachedTx;
      } else {
        tx = await wallet.createTx(
          destinationAddress,
          amountUnits,
          _isSweepAll,
          priority: _selectedPriority + 1,
        );
      }

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        final committed = await showConfirmSendSheet(
          context,
          ConfirmSendScreenArgs(
            coinSymbol: _coinSymbol,
            tx: tx,
            destinationAddress: destinationAddress,
            destinationOpenAlias: destinationOpenAlias,
            destinationContactName: _selectedContact?.name,
          ),
        );
        if (committed == true && mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/coin_home',
            // remove until the coin home screen is reached
            (route) => route.settings.name == '/wallet_home',
            arguments: CoinHomeScreenArgs(coinSymbol: _coinSymbol, showTxSuccessToast: true),
          );
        }
      }
    } catch (error) {
      if (error.toString().contains('Insufficient gas funds')) {
        setState(() {
          _amountError = i18n.sendInsufficientGasError;
        });
      } else if (error.toString().contains('Unlocked funds too low')) {
        if ((_compareAmountToBalance(wallet) ?? 0) < 0) {
          setState(() {
            _amountError = i18n.sendInsufficientBalanceToCoverFeeError;
          });
        } else {
          setState(() {
            _amountError = i18n.sendInsufficientBalanceError;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.unknownError)));
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _setBalanceAsSendAmount() {
    final wallet = _wallet(context);
    final units = wallet.unlockedBalanceBaseUnits;
    _amountController.text = units == null
        ? ''
        : baseUnitsToDecimalString(units, wallet.baseUnitDecimals);

    setState(() {
      _isSweepAll = true;
    });
  }

  void _setPriority(int priority) {
    if (priority == _selectedPriority) return;
    // Fees for all three priorities are computed together in _calculateFees, so
    // switching just re-reads the cached one (no recalculation needed).
    setState(() => _selectedPriority = priority);
    _feeRevision.value++;
  }

  void _onAddressChanged() {
    // The controller also notifies on selection changes — setting text emits a
    // second, selection-only fire a frame later. Ignore those, or that fire
    // would wipe the invalid-address error a paste just set.
    final text = _destinationAddressController.text;
    if (text == _lastAddressText) return;
    _lastAddressText = text;

    // Input changed: invalidate the resolution cache + clear any stale error.
    _resolveCacheInput = '';
    _resolveCacheOutput = '';
    if (_destinationAddressError.isNotEmpty) {
      setState(() => _destinationAddressError = '');
    }

    final isOpenAliasDomain = domainRegex.hasMatch(text) && _wallet(context).aliasAsset.isNotEmpty;

    // While the user is actively typing a domain, defer the (network) OpenAlias
    // resolution until the field unfocuses. Just clear fees + disable send.
    if (isOpenAliasDomain && _addressFocusNode.hasFocus) {
      _feeDebounce?.cancel();
      _feeCalculationCounter++;
      setState(() {
        _fees = null;
        _isLoadingFees = false;
        _feesInProgress = false;
        _formValid = false;
      });
      _feeRevision.value++;
      return;
    }

    _scheduleFeeCalculation();
  }

  void _onAmountChanged() {
    final wallet = _wallet(context);
    final isFullBalance = _compareAmountToBalance(wallet) == 0;

    if (isFullBalance && !_isSweepAll) {
      setState(() {
        _isSweepAll = true;
      });
    }

    if (!isFullBalance && _isSweepAll) {
      setState(() {
        _isSweepAll = false;
      });
    }

    _scheduleFeeCalculation();
  }

  void _scheduleFeeCalculation() {
    _feeDebounce?.cancel();
    _feeDebounce = Timer(Duration(milliseconds: 400), () {
      unawaited(_calculateFeesIfValid());
    });
  }

  Future<void> _calculateFeesIfValid() async {
    final wallet = _wallet(context);
    final amountUnits = _amountUnits(wallet);

    if (amountUnits == null ||
        amountUnits <= BigInt.zero ||
        (_compareAmountToBalance(wallet) ?? 1) > 0) {
      _feeCalculationCounter++;
      _lastFeeFetchKey = '';
      if (mounted) {
        setState(() {
          _isLoadingFees = false;
          _feesInProgress = false;
          _fees = null;
          _formValid = false;
        });
        _feeRevision.value++;
      }
      return;
    }

    final valid = await _validateForm(setErrors: false);
    if (mounted) setState(() => _formValid = valid);
    if (valid) {
      await _calculateFees();
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final walletManager = context.watch<WalletManager>();
    final wallet = walletManager.getWallet(_coinSymbol);

    if (wallet == null) {
      return Scaffold(
        backgroundColor: BrandColors.paper,
        body: SafeArea(
          child: Center(child: Text('Unknown coin: $_coinSymbol', style: BrandText.body)),
        ),
      );
    }

    final fiatRate = context.watch<FiatRateModel>();
    final fiatSymbol = consts.currencySymbols[fiatRate.fiatCode] ?? '\$';
    final coinRate = fiatRate.rateFor(wallet.coinSymbol);

    return Scaffold(
      backgroundColor: BrandColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(i18n),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 26, 16, 16),
                    children: [
                      _sectionLabel(i18n.sendFromLabel),
                      _fromCard(
                        wallet,
                        assetsOnChainOf(walletManager, wallet),
                        fiatRate,
                        fiatSymbol,
                      ),
                      const SizedBox(height: 14),
                      _sectionLabel(i18n.sendToLabel),
                      _toCard(wallet, i18n),
                      if (_destinationAddressError.isNotEmpty) _errorText(_destinationAddressError),
                      const SizedBox(height: 14),
                      _sectionLabel(i18n.amount),
                      _amountCard(wallet, i18n, fiatSymbol, coinRate),
                      if (_amountError.isNotEmpty) _errorText(_amountError),
                      const SizedBox(height: 14),
                      _sectionLabel(i18n.sendPriorityHeading),
                      _prioritySection(wallet, i18n, fiatSymbol, coinRate),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      BrandButton.ghost(
                        label: i18n.cancel,
                        color: BrandColors.inkMuted,
                        expand: false,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: BrandButton(
                          label: i18n.sendSendButton,
                          loading: _isLoading,
                          onPressed: (_formValid && _openAliasResolving == 0 && !_isLoading)
                              ? _send
                              : null,
                        ),
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

  Widget _header(AppLocalizations i18n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: BrandScreenHeader(
        onBack: () => Navigator.pop(context),
        center: Text(i18n.sendTitle, style: BrandText.appBar.copyWith(fontSize: 16)),
      ),
    );
  }

  Widget _sectionLabel(String text) =>
      SectionHeader(label: text, padding: const EdgeInsets.only(left: 4, bottom: 8));

  Widget _errorText(String text) => Padding(
    padding: const EdgeInsets.only(top: 6, left: 4),
    child: Text(text, style: BrandText.caption.copyWith(color: BrandColors.error)),
  );

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    Color? borderColor,
  }) {
    return BrandCard(padding: padding, borderColor: borderColor, child: child);
  }

  Widget _fromCard(
    CryptoWallet wallet,
    List<CryptoWallet> assets,
    FiatRateModel fiatRate,
    String fiatSymbol,
  ) {
    final canChoose = assets.length > 1;
    final card = AnimatedContainer(
      duration: BrandMotion.transition,
      decoration: BoxDecoration(color: BrandColors.card, borderRadius: BorderRadius.circular(16)),
      // Border drawn over the content (CSS border-box) so thickening it on open
      // doesn't shift the layout.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _assetMenuOpen ? BrandColors.cinnamon : BrandColors.border,
          width: _assetMenuOpen ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          CoinMark(coinSymbol: wallet.coinSymbol, iconAsset: wallet.iconAsset, size: 32),
          const SizedBox(width: 12),
          Expanded(child: _assetLabel(wallet)),
          if (canChoose)
            AnimatedRotation(
              turns: _assetMenuOpen ? 0.5 : 0,
              duration: BrandMotion.transition,
              child: Icon(Icons.keyboard_arrow_down, size: 20, color: BrandColors.inkMuted),
            ),
        ],
      ),
    );
    if (!canChoose) return card;
    return CompositedTransformTarget(
      link: _assetMenuLink,
      child: OverlayPortal(
        controller: _assetMenuController,
        overlayChildBuilder: (ctx) => _assetDropdown(ctx, assets, fiatRate, fiatSymbol),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleAssetMenu,
          child: card,
        ),
      ),
    );
  }

  void _toggleAssetMenu() {
    setState(() => _assetMenuOpen = !_assetMenuOpen);
    if (_assetMenuOpen) {
      FocusScope.of(context).unfocus();
      _assetMenuController.show();
    } else {
      _assetMenuController.hide();
    }
  }

  void _closeAssetMenu() {
    if (!_assetMenuOpen) return;
    setState(() => _assetMenuOpen = false);
    _assetMenuController.hide();
  }

  Widget _assetDropdown(
    BuildContext ctx,
    List<CryptoWallet> assets,
    FiatRateModel fiatRate,
    String fiatSymbol,
  ) {
    final width = math.min(MediaQuery.of(ctx).size.width, 480.0) - 32;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _closeAssetMenu),
        ),
        CompositedTransformFollower(
          link: _assetMenuLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: SizedBox(
            width: width,
            child: Material(
              color: Colors.transparent,
              child: BrandCard(
                radius: 20,
                clipBehavior: Clip.antiAlias,
                shadow: const [
                  BoxShadow(color: Color(0x1F2C170C), blurRadius: 24, offset: Offset(0, 12)),
                ],
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final asset in assets) _assetDropdownRow(asset, fiatRate, fiatSymbol),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _assetDropdownRow(CryptoWallet asset, FiatRateModel fiatRate, String fiatSymbol) {
    final i18n = AppLocalizations.of(context)!;
    final configured = asset.connectionAddress.isNotEmpty;
    final selected = asset.coinSymbol == _coinSymbol;
    final balance = asset.unlockedBalance;
    final rate = fiatRate.rateFor(asset.coinSymbol);
    final fiat = (rate != null && balance is double && !fiatRate.isDisabled)
        ? balance * rate
        : null;
    final subtitle = !configured
        ? i18n.homeNoConnection
        : (balance is double
              ? formatAmount(balance, asset.decimals, symbol: asset.coinSymbol)
              : '—');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? BrandColors.surfaceSunken : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _closeAssetMenu();
            _selectAsset(asset.coinSymbol);
          },
          child: Opacity(
            opacity: configured ? 1 : 0.5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
              child: Row(
                children: [
                  CoinMark(coinSymbol: asset.coinSymbol, iconAsset: asset.iconAsset, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asset.coinName,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                            color: BrandColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: 'Ubuntu Mono',
                            fontSize: 11.5,
                            height: 1.3,
                            color: BrandColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fiat != null ? '$fiatSymbol${NumberFormat('#,##0').format(fiat)}' : '—',
                    style: TextStyle(
                      fontFamily: 'Ubuntu Mono',
                      fontSize: 13,
                      color: BrandColors.inkMuted,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check, size: 18, color: BrandColors.cinnamon),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _assetLabel(CryptoWallet wallet) {
    final i18n = AppLocalizations.of(context)!;
    final balance = wallet.unlockedBalance;
    final available = balance == null
        ? '—'
        : '${formatAmount(balance, wallet.decimals)} ${i18n.sendAvailableSuffix}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          wallet.coinName,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            height: 1.25,
            color: BrandColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          available,
          style: TextStyle(
            fontFamily: 'Ubuntu Mono',
            fontSize: 11.5,
            height: 1.3,
            color: BrandColors.inkMuted,
          ),
        ),
      ],
    );
  }

  /// Switches the send form to a different asset on the same chain. The picker
  /// only offers same-chain assets (all EVM), which share an address format, so
  /// the destination is kept; only the amount and fee state (asset-specific) reset.
  void _selectAsset(String coinSymbol) {
    if (coinSymbol == _coinSymbol) return;
    setState(() {
      _coinSymbol = coinSymbol;
      _isSweepAll = false;
      _fees = null;
      _isLoadingFees = false;
      _feesInProgress = false;
      _formValid = false;
      _amountError = '';
      _lastFeeFetchKey = '';
    });
    _feeCalculationCounter++;
    _amountController.clear(); // fires _onAmountChanged → revalidates for the new asset
  }

  Widget _toCard(CryptoWallet wallet, AppLocalizations i18n) {
    if (_selectedContact != null) {
      return _card(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: BrandColors.cinnamonDeep, shape: BoxShape.circle),
              child: Text(
                _selectedContact!.name.isNotEmpty ? _selectedContact!.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.onCinnamon,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedContact!.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: BrandColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    shortenMiddle(_destinationAddressController.text, head: 8, tail: 10),
                    style: TextStyle(
                      fontFamily: 'Ubuntu Mono',
                      fontSize: 11,
                      color: BrandColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _clearSelectedContact,
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BrandColors.surfaceSunken,
                  shape: BoxShape.circle,
                  border: Border.all(color: BrandColors.border),
                ),
                child: Icon(Icons.close, size: 15, color: BrandColors.ink),
              ),
            ),
          ],
        ),
      );
    }

    final isMobile = Platform.isAndroid || Platform.isIOS;
    return _card(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      borderColor: _destinationAddressError.isNotEmpty ? BrandColors.error : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _destinationAddressController,
            focusNode: _addressFocusNode,
            maxLines: null,
            textInputAction: TextInputAction.done,
            style: TextStyle(
              fontFamily: 'Ubuntu Mono',
              fontSize: 13.5,
              height: 1.5,
              color: BrandColors.ink,
            ),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              // Anchor the label to the settlement chain, not the asset — a DAI
              // send goes to an "Ethereum address", not a "Dai address".
              hintText: i18n.sendAddressHint(
                chainNameOf(Provider.of<WalletManager>(context, listen: false), wallet),
              ),
              hintStyle: TextStyle(
                fontFamily: 'Ubuntu Mono',
                fontSize: 13.5,
                height: 1.5,
                color: BrandColors.inkMuted,
              ),
              suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: _openAliasResolving > 0
                  ? Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: BrandColors.cinnamon,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: BrandColors.surfaceTinted),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MiniActionButton(
                  icon: Icons.content_paste_outlined,
                  label: i18n.sendPasteButton,
                  onTap: _pasteAddressFromClipboard,
                ),
              ),
              if (isMobile) ...[
                const SizedBox(width: 7),
                Expanded(
                  child: MiniActionButton(
                    icon: Icons.qr_code_scanner,
                    label: i18n.sendScanButton,
                    onTap: _scanQrCode,
                  ),
                ),
              ],
              const SizedBox(width: 7),
              Expanded(
                child: MiniActionButton(
                  icon: Icons.person_outline,
                  label: i18n.sendContactsButton,
                  onTap: _showContactPicker,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amountCard(
    CryptoWallet wallet,
    AppLocalizations i18n,
    String fiatSymbol,
    double? coinRate,
  ) {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final amountFiat = coinRate != null ? amount * coinRate : 0.0;
    return _card(
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+(\.\d*)?'))],
                  style: TextStyle(
                    fontFamily: 'Ubuntu Mono',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: BrandColors.ink,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: '0.000000',
                    hintStyle: TextStyle(
                      fontFamily: 'Ubuntu Mono',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: BrandColors.inkFaint,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                wallet.coinSymbol,
                style: TextStyle(
                  fontFamily: 'Ubuntu Mono',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.inkMuted,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _setBalanceAsSendAmount,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
                  decoration: BoxDecoration(
                    color: BrandColors.surfaceAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    i18n.sendMaxButton,
                    style: TextStyle(
                      fontFamily: 'Ubuntu Mono',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: BrandColors.cinnamonDeep,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Container(height: 1, color: BrandColors.surfaceTinted),
          const SizedBox(height: 11),
          Text(
            '≈ ${formatFiat(amountFiat, fiatSymbol)}',
            style: TextStyle(fontFamily: 'Ubuntu Mono', fontSize: 12, color: BrandColors.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _prioritySection(
    CryptoWallet wallet,
    AppLocalizations i18n,
    String fiatSymbol,
    double? coinRate,
  ) {
    return Column(
      children: [
        BrandSegmented(
          labels: [i18n.sendPriorityLow, i18n.sendPriorityNormal, i18n.sendPriorityHigh],
          selectedIndex: _selectedPriority,
          onSelect: _setPriority,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 11, 4, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                i18n.sendNetworkFee,
                style: TextStyle(fontSize: 12, color: BrandColors.inkMuted),
              ),
              _feeValue(wallet, fiatSymbol, coinRate),
            ],
          ),
        ),
      ],
    );
  }

  Widget _feeValue(CryptoWallet wallet, String fiatSymbol, double? coinRate) {
    final feeTx = (_fees != null && _fees!.length > _selectedPriority)
        ? _fees![_selectedPriority]
        : null;
    if (_isLoadingFees || (_feesInProgress && feeTx == null)) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: BrandColors.cinnamon),
      );
    }
    if (feeTx == null) {
      return Text(
        '—',
        style: TextStyle(fontFamily: 'Ubuntu Mono', fontSize: 12, color: BrandColors.inkMuted),
      );
    }
    final fee = displayAmount(feeTx.feeBaseUnits, wallet.feeBaseUnitDecimals);
    final feeStr = formatAmount(fee, wallet.feeDecimals, symbol: wallet.feeCoinSymbol);
    final feeFiat = (coinRate != null && !wallet.feeIsForeign)
        ? ' · ${formatFiat(fee * coinRate, fiatSymbol)}'
        : '';
    return Text(
      '$feeStr$feeFiat',
      style: TextStyle(fontFamily: 'Ubuntu Mono', fontSize: 12, color: BrandColors.inkMuted),
    );
  }
}

/// Bottom sheet for picking a contact to send to. Send already knows the chain,
/// so each contact shows its address on that chain; contacts without one are
/// greyed out and unselectable rather than offering a send that cannot complete.
class _ContactPickerSheet extends StatefulWidget {
  final CryptoWallet chain;
  final ValueChanged<Contact> onSelected;

  const _ContactPickerSheet({required this.chain, required this.onSelected});

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final chainSymbol = widget.chain.coinSymbol;

    final mq = MediaQuery.of(context);
    // Fixed height so filtering the results — or getting none — never shrinks the
    // sheet. Capped to the space above the keyboard, and below the status bar
    // (viewPadding.top, since padding.top reads 0 inside a modal sheet).
    final available = mq.size.height - mq.viewInsets.bottom - mq.viewPadding.top - 40;
    final height = math.min(mq.size.height * 0.72, available);

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CoinMark(
                            coinSymbol: chainSymbol,
                            iconAsset: widget.chain.iconAsset,
                            size: 34,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(i18n.sendPickContactTitle, style: BrandText.sheetTitle),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        i18n.sendPickContactSubtitle(widget.chain.coinName),
                        style: BrandText.bodyMuted.copyWith(fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                  child: BrandCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 18, color: BrandColors.inkFaint),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (q) => setState(() => _query = q),
                            textInputAction: TextInputAction.search,
                            style: TextStyle(fontSize: 13.5, color: BrandColors.ink),
                            decoration: InputDecoration(
                              isCollapsed: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              border: InputBorder.none,
                              hintText: i18n.addressBookSearchHint,
                              hintStyle: TextStyle(fontSize: 13.5, color: BrandColors.inkFaint),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Consumer<ContactModel>(
                    builder: (context, contactModel, child) {
                      final results = contactModel.searchContacts(_query);
                      if (results.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                            child: Text(
                              _query.isEmpty
                                  ? i18n.addressBookNoContactsForCoin(chainSymbol)
                                  : i18n.addressBookNoSearchResults,
                              style: BrandText.bodyMuted.copyWith(fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      // Selectable contacts (with an address on this chain) first.
                      bool has(Contact c) => c.addressFor(chainSymbol) != null;
                      final ordered = [...results.where(has), ...results.where((c) => !has(c))];
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        itemCount: ordered.length,
                        itemBuilder: (context, index) => _ContactPickRow(
                          contact: ordered[index],
                          chain: widget.chain,
                          onTap: () => widget.onSelected(ordered[index]),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                  child: BrandButton.ghost(
                    label: i18n.cancel,
                    color: BrandColors.inkMuted,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One contact in the send picker. Selectable when it has an address on the
/// send's chain; otherwise greyed out, showing why (which chain it does have).
class _ContactPickRow extends StatelessWidget {
  final Contact contact;
  final CryptoWallet chain;
  final VoidCallback onTap;

  const _ContactPickRow({required this.contact, required this.chain, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final address = contact.addressFor(chain.coinSymbol);
    final enabled = address != null;
    final initial = contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?';
    // Enabled: this chain's badge + address. Disabled: the first chain the
    // contact does have, so the "No X address" reason reads honestly.
    final badgeSymbol = enabled
        ? chain.coinSymbol
        : (contact.addresses.keys.isNotEmpty ? contact.addresses.keys.first : chain.coinSymbol);

    final row = Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandColors.surfaceTinted)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? BrandColors.cinnamonDeep : BrandColors.inkDisabled,
            ),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: BrandColors.onCinnamon,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: BrandColors.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    CoinMark(coinSymbol: badgeSymbol, iconAsset: '', size: 18),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        enabled
                            ? shortenMiddle(address, head: 8, tail: 10)
                            : i18n.sendContactNoAddress(chain.coinName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: enabled ? 'Ubuntu Mono' : null,
                          fontSize: 11,
                          color: BrandColors.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (enabled) ...[
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 20, color: BrandColors.inkDisabled),
          ],
        ],
      ),
    );

    if (!enabled) return Opacity(opacity: 0.45, child: row);
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
  }
}
