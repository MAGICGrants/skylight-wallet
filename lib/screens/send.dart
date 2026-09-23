import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:wallet_domain/wallet_domain.dart' show baseUnitsToDecimalString, decimalToBaseUnits;

import 'package:skylight_wallet/consts.dart' as consts;
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/app_wallet.dart';
import 'package:skylight_wallet/models/contact_model.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/models/wallet_types.dart';
import 'package:skylight_wallet/screens/desktop/home_shell.dart';
import 'package:skylight_wallet/util/formatting.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/platform.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

class SendScreenArgs {
  String destinationAddress;

  /// Exact decimal text, never a double: this is a spend amount.
  String? amount;

  /// Set when the address came from a contact (e.g. Send in the address book),
  /// so Send opens showing the contact card rather than a bare address.
  final Contact? contact;

  SendScreenArgs({required this.destinationAddress, this.amount, this.contact});
}

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

/// Matches an OpenAlias: an FQDN, optionally written email-style
/// (`donate@example.org`, which resolves as `donate.example.org`). Monero
/// addresses are base58 and contain neither a dot nor an '@', so they are never
/// mistaken for one. Internationalized names must be entered as A-labels
/// (`xn--mnchen-3ya.example`).
final domainRegex = RegExp(
  r'^(?:[A-Za-z0-9._%+-]+@)?(?!-)[A-Za-z0-9-]{1,63}(?<!-)'
  r'(\.(?!-)[A-Za-z0-9-]{1,63}(?<!-))*'
  r'\.(?:[A-Za-z]{2,}|xn--[A-Za-z0-9-]{2,})$',
);

/// How long the address field must sit still before an alias is resolved.
const _openAliasTypingDelay = Duration(milliseconds: 600);

/// Sentinel spliced into the high-fee warning so the shared confirm-send view
/// can bold the percentage regardless of locale. Must not be a space or any
/// substring of the sentence, since the view splits on it — the sentence is
/// full of spaces, so a NUL marker is used.
const _highFeeToken = '\u0000';

class _SendScreenState extends State<SendScreen> {
  bool _isLoading = false;
  bool _isLoadingFees = false;
  final _destinationAddressController = TextEditingController(text: '');
  final _amountController = TextEditingController(text: '');
  bool _isSweepAll = false;
  Contact? _selectedContact;
  List<int?>? _fees; // estimated fee (piconero) per priority; null = estimate failed
  int _selectedPriority = 1; // 0=Low, 1=Normal, 2=High
  int _feeCalculationCounter = 0; // Track the latest fee calculation request
  String _lastFeeFetchKey = '';

  String _destinationAddressError = '';
  String _amountError = '';

  bool _formValid = false; // gates the send button
  int _openAliasResolving = 0; // >0 while OpenAlias resolution is in flight
  bool _didInit = false; // one-time setup guard for didChangeDependencies

  // Caches the last OpenAlias resolution + dedupes concurrent lookups so
  // re-validation (amount changes, revalidations) doesn't re-hit Tor.
  String? _resolveCacheInput;
  ResolvedOpenAlias? _resolveCacheOutput;
  Future<ResolvedOpenAlias?>? _resolveInFlight;
  String _resolveInFlightInput = '';

  @override
  void dispose() {
    _destinationAddressController.removeListener(_onAddressChanged);
    _amountController.removeListener(_onAmountChanged);
    _destinationAddressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Run once. didChangeDependencies fires on every AppWallet notify (via
    // context.watch), and re-adding listeners / re-resolving OpenAlias here
    // would loop the (slow, over-Tor) resolver forever.
    if (_didInit) return;
    _didInit = true;

    _loadFormFromArgs();
    _destinationAddressController.addListener(_onAddressChanged);
    _amountController.addListener(_onAmountChanged);
    // Validate any prefilled values (contact/QR args) so the button reflects them.
    _revalidate();
  }

  void _loadFormFromArgs() {
    final args = ModalRoute.of(context)!.settings.arguments as SendScreenArgs?;

    if (args != null) {
      _destinationAddressController.text = args.destinationAddress;
      _amountController.text = args.amount ?? '';
      // Same field the in-send picker sets, so the contact card renders here too.
      _selectedContact = args.contact;
    }
  }

  void _pasteAddressFromClipboard() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);

    if (data != null) {
      _destinationAddressController.text = data.text ?? '';
    }
  }

  Future<void> _scanQrCode() async {
    final wallet = appWalletOf(context);
    final i18n = AppLocalizations.of(context)!;

    final result = await Navigator.pushNamed(context, '/scan_qr');

    if (result == null || result is! String) return;

    String address = '';
    String? amount;
    final uri = Uri.tryParse(result);

    if (uri != null && uri.scheme == 'monero') {
      if (!wallet.isAddressValid(uri.path)) {
        if (mounted) {
          showBrandToast(context, i18n.sendInvalidAddressError);
        }
        return;
      }

      address = uri.path;

      amount = uri.queryParameters['tx_amount'];
    } else if (wallet.isAddressValid(result)) {
      address = result;
    } else {
      if (mounted) {
        showBrandToast(context, i18n.sendInvalidAddressError);
      }
      return;
    }

    _destinationAddressController.text = address;
    if (amount != null) {
      _amountController.text = _asExactAmount(amount);
    }
  }

  /// A scanned amount as Monero can actually express it.
  ///
  /// Text the whole way. Parsing to a double and back is what used to change
  /// the value; base units are exact, so this round trip can only drop digits
  /// finer than one piconero — and it shows the user the amount that will
  /// really be spent instead of one that gets truncated later.
  ///
  /// Unparseable input goes in the field verbatim, so the form's own validation
  /// rejects it and the user can see what was scanned.
  String _asExactAmount(String raw) {
    try {
      return baseUnitsToDecimalString(decimalToBaseUnits(raw, _xmrDecimals), _xmrDecimals);
    } on FormatException {
      return raw;
    }
  }

  void _showContactPicker() async {
    final i18n = AppLocalizations.of(context)!;
    final contactModel = Provider.of<ContactModel>(context, listen: false);

    final contact = await showContactPickerSheet<Contact>(
      context: context,
      labels: ContactPickerLabels(
        title: i18n.sendPickContactTitle,
        searchHint: i18n.addressBookSearchHint,
        cancel: i18n.cancel,
        noContacts: i18n.addressBookNoContacts,
        noResults: i18n.addressBookNoSearchResults,
      ),
      headerIcon: SheetIcon(
        icon: Icons.people,
        bg: BrandColors.surfaceTinted,
        color: BrandColors.primaryDeep,
      ),
      // Skylight contacts hold a single Monero address, so every one is
      // selectable.
      search: (query) => [
        for (final c in contactModel.searchContacts(query))
          ContactPickerEntry<Contact>(
            value: c,
            name: c.name,
            addressShort: _shortenMiddle(c.addressFor('XMR') ?? '', head: 8, tail: 10),
          ),
      ],
    );

    if (contact == null || !mounted) return;
    setState(() {
      _selectedContact = contact;
      _destinationAddressController.text = contact.addressFor('XMR') ?? '';
    });
  }

  void _clearSelectedContact() {
    _destinationAddressController.text = '';

    setState(() {
      _selectedContact = null;
    });
  }

  Future<String> _resolveDestinationAddress() async {
    final unresolvedDestinationAddress = _destinationAddressController.text;

    if (domainRegex.hasMatch(unresolvedDestinationAddress)) {
      return (await _resolveDomain(unresolvedDestinationAddress))?.address ?? '';
    }
    return unresolvedDestinationAddress;
  }

  /// Resolves an OpenAlias [domain] once, caching the result and joining any
  /// in-flight lookup of the same domain so amount changes / revalidations
  /// don't re-hit the (slow, over-Tor) resolver. Drives `_openAliasResolving`.
  Future<ResolvedOpenAlias?> _resolveDomain(String domain) async {
    if (domain == _resolveCacheInput) return _resolveCacheOutput;
    if (_resolveInFlight != null && domain == _resolveInFlightInput) {
      return _resolveInFlight!;
    }

    final wallet = appWalletOf(context);
    if (mounted) setState(() => _openAliasResolving++);

    try {
      // Wait for the field to settle first. It revalidates on every keystroke
      // and a half-typed domain ("privacyguides.magicgra") matches the alias
      // pattern too, so without this one alias would cost a round of Tor
      // lookups per character. If the user typed on, the newer text has its own
      // call and this one is abandoned.
      await Future.delayed(_openAliasTypingDelay);
      if (!mounted || _destinationAddressController.text != domain) return null;

      // Someone may have resolved this exact alias while we were settling.
      if (domain == _resolveCacheInput) return _resolveCacheOutput;
      if (_resolveInFlight != null && domain == _resolveInFlightInput) {
        return _resolveInFlight!;
      }

      // Only a real lookup is published as in-flight, so joining one always
      // yields a real answer rather than an abandoned attempt.
      final future = wallet.resolveOpenAlias(domain);
      _resolveInFlight = future;
      _resolveInFlightInput = domain;

      try {
        final resolved = await future;
        _resolveCacheInput = domain;
        _resolveCacheOutput = resolved;
        return resolved;
      } finally {
        if (identical(_resolveInFlight, future)) {
          _resolveInFlight = null;
          _resolveInFlightInput = '';
        }
      }
    } finally {
      if (mounted) setState(() => _openAliasResolving--);
    }
  }

  Future<bool> _validateForm({bool setErrors = true}) async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final unresolvedDestinationAddress = _destinationAddressController.text;

    if (amount == 0) {
      return false;
    }

    final wallet = appWalletOf(context);
    final i18n = AppLocalizations.of(context)!;

    if (domainRegex.hasMatch(unresolvedDestinationAddress)) {
      // OpenAlias: cached + deduped; the counter gates the send button while
      // a lookup is in flight.
      if (await _resolveDomain(unresolvedDestinationAddress) == null) {
        if (setErrors) {
          setState(() {
            _destinationAddressError = i18n.sendOpenAliasResolveError;
          });
        }
        return false;
      }
    } else if (!wallet.isAddressValid(unresolvedDestinationAddress)) {
      if (setErrors) {
        setState(() {
          _destinationAddressError = i18n.sendInvalidAddressError;
        });
      }
      return false;
    }

    if (_amountUnits() > (wallet.unlockedBalanceBaseUnits ?? BigInt.zero)) {
      if (setErrors) {
        setState(() {
          _amountError = i18n.sendInsufficientBalanceError;
        });
        return false;
      }
    }

    return true;
  }

  Future<void> _calculateFees() async {
    final feeFetchKey = '${_destinationAddressController.text}-${_amountController.text}';

    if (feeFetchKey == _lastFeeFetchKey) {
      return;
    }

    _lastFeeFetchKey = feeFetchKey;

    final i18n = AppLocalizations.of(context)!;
    final wallet = appWalletOf(context);

    // Increment counter to mark this as the latest request
    _feeCalculationCounter++;
    final currentRequest = _feeCalculationCounter;

    setState(() {
      _isLoadingFees = true;
      _fees = null;
    });

    final destinationAddress = await _resolveDestinationAddress();
    final amountText = _amountController.text;

    try {
      // Estimate the fee per priority natively (no full tx build).
      final fees = await Future.wait([
        wallet.estimateFee(destinationAddress, amountText, priority: 1),
        wallet.estimateFee(destinationAddress, amountText, priority: 2),
        wallet.estimateFee(destinationAddress, amountText, priority: 3),
      ]);

      // Only update state if this is still the latest request
      if (currentRequest == _feeCalculationCounter && mounted) {
        setState(() {
          _fees = fees;
          _isLoadingFees = false;

          // If there is not enough balance for the selected priority,
          // find the highest priority the user can pay for and select it
          if (_fees?[_selectedPriority] == null) {
            for (int i = _selectedPriority; i >= 0; i--) {
              if (_fees?[i] != null) {
                _selectedPriority = i;
                break;
              }
            }
          }
        });
      }
    } catch (error) {
      // Let the same address+amount be asked again. The key is claimed before
      // the work starts, so without this a single failure pins the fee at '—'
      // for that pair forever: every later revalidation matches the key and
      // returns early, and only editing the address or amount can clear it.
      _lastFeeFetchKey = '';

      // Only update state if this is still the latest request
      if (currentRequest == _feeCalculationCounter && mounted) {
        setState(() {
          _isLoadingFees = false;
        });

        showBrandToast(context, i18n.sendFailedToGetFeesError);
      }
    }
  }

  Future<void> _send() async {
    final wallet = appWalletOf(context);
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
    String destinationAddress = '';
    String? destinationOpenAlias;
    String? destinationOpenAliasName;

    // Resolve openalias if it is a domain. Validation above already resolved
    // it, so this comes back from the cache rather than hitting Tor again.
    if (domainRegex.hasMatch(destinationAddressUnresolved)) {
      final resolved = await _resolveDomain(destinationAddressUnresolved);

      if (resolved == null) {
        setState(() {
          _isLoading = false;
          _destinationAddressError = i18n.sendOpenAliasResolveError;
        });
        return;
      }

      destinationAddress = resolved.address;
      destinationOpenAlias = destinationAddressUnresolved;
      destinationOpenAliasName = resolved.recipientName;
    } else {
      destinationAddress = destinationAddressUnresolved;
    }

    try {
      // Build the real transaction for the selected priority (fees shown on the
      // screen are estimates, not tx objects, so always construct here).
      final tx = await wallet.createTx(
        destinationAddress,
        _amountController.text,
        _isSweepAll,
        priority: _selectedPriority + 1,
      );

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        await _openConfirmSheet(
          tx: tx,
          destinationAddress: destinationAddress,
          destinationOpenAlias: destinationOpenAlias,
          destinationOpenAliasName: destinationOpenAliasName,
        );
      }
    } catch (error) {
      if (error.toString().contains('Unlocked funds too low')) {
        // Display-only: picks which of two error messages to show, so the
        // imprecision of a double cannot reach an amount anyone spends.
        final approxAmount = double.tryParse(_amountController.text) ?? 0;
        if (wallet.unlockedBalance! > approxAmount) {
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
          showBrandToast(context, i18n.unknownError);
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  /// Opens the shared confirm-send bottom sheet, committing on confirm and,
  /// on success, routing to the wallet home with the success toast (matching
  /// the retired full-screen confirm route).
  Future<void> _openConfirmSheet({
    required AppPendingTx tx,
    required String destinationAddress,
    String? destinationOpenAlias,
    String? destinationOpenAliasName,
  }) async {
    final i18n = AppLocalizations.of(context)!;
    final fiatRate = Provider.of<FiatRateModel>(context, listen: false);
    final fiatSymbol = fiatRate.fiatCode == 'EUR' ? '€' : '\$';
    final xmrRate = fiatRate.rateFor('XMR');
    final amountFiat = xmrRate is double ? tx.amount * xmrRate : null;
    final feeFiat = xmrRate is double ? tx.fee * xmrRate : null;

    // Monero fee is same-currency, so compare directly. Warn when it's ≥10% of
    // the amount (mirrors Spice's confirm-send high-fee guard).
    final feeRatio = tx.amount > 0 ? tx.fee / tx.amount : null;
    final showHighFeeWarning = feeRatio != null && feeRatio > 0.10;

    final committed = await showConfirmSendSheet(
      context: context,
      labels: ConfirmSendLabels(
        title: i18n.confirmSendTitle,
        description: i18n.confirmSendDescription,
        amount: i18n.amount,
        networkFee: i18n.networkFee,
        address: i18n.address,
        send: i18n.sendSendButton,
        cancel: i18n.cancel,
      ),
      coinSymbol: 'XMR',
      amountText: '${tx.amount.toStringAsFixed(12)} XMR',
      amountFiat: amountFiat != null ? formatFiat(amountFiat, fiatSymbol) : null,
      feeText: '${tx.fee.toStringAsFixed(12)} XMR',
      feeFiat: feeFiat != null ? formatFiat(feeFiat, fiatSymbol) : null,
      address: destinationAddress,
      openAlias: destinationOpenAlias,
      openAliasName: destinationOpenAliasName,
      contactName: _selectedContact?.name,
      showHighFeeWarning: showHighFeeWarning,
      highFeeWarning: showHighFeeWarning ? i18n.confirmSendHighFeeWarning(_highFeeToken) : null,
      highFeeToken: _highFeeToken,
      highFeePercent: showHighFeeWarning ? '${(feeRatio * 100).round()}%' : null,
      onConfirm: () => _commitTx(tx, destinationAddress),
    );

    if (committed == true && mounted) {
      Navigator.pushNamed(context, '/wallet_home', arguments: {'showTxSuccessToast': true});
    }
  }

  /// Commits the transaction; surfaces its own errors as snackbars (matching the
  /// retired confirm screen) and rethrows so the sheet stays open on failure.
  Future<void> _commitTx(AppPendingTx tx, String destinationAddress) async {
    final i18n = AppLocalizations.of(context)!;
    final wallet = appWalletOf(context);

    try {
      await wallet.commitTx(tx, destinationAddress);
    } on FormatException catch (error) {
      var errorMsg = error.toString().replaceFirst('FormatException: ', '');
      if (error.toString().contains('HTTP error code 500')) {
        errorMsg = 'Failed to send transaction. You might have insufficient unlocked balance.';
      }
      if (mounted) {
        showBrandToast(context, errorMsg);
      }
      rethrow;
    } catch (error) {
      log(LogLevel.error, error.toString());
      if (mounted) {
        showBrandToast(context, i18n.unknownError);
      }
      rethrow;
    }
  }

  void _setBalanceAsSendAmount() {
    final wallet = appWalletOf(context);
    // From base units, not from the display double: Max fills a field that is
    // about to be spent, and a balance over ~9007 XMR does not survive a double
    // intact. Sweep-all normally makes the amount moot, but editing the field
    // clears that flag and the number becomes the real amount.
    final units = wallet.unlockedBalanceBaseUnits;
    _amountController.text = units == null ? '' : baseUnitsToDecimalString(units, _xmrDecimals);

    setState(() {
      _isSweepAll = true;
    });
  }

  void _setPriority(int priority) {
    if (priority == _selectedPriority) return;
    setState(() => _selectedPriority = priority);
  }

  /// Re-runs validation (without surfacing errors) and updates the send-button
  /// gate. Kicks off fee calculation when the form is valid.
  Future<void> _revalidate() async {
    final valid = await _validateForm(setErrors: false);
    if (mounted) setState(() => _formValid = valid);
    if (valid) _calculateFees();
  }

  Future<void> _onAddressChanged() async {
    // Setting text also clears a stale inline error so a corrected address
    // doesn't keep showing the old warning.
    if (_destinationAddressError.isNotEmpty) {
      setState(() => _destinationAddressError = '');
    }
    await _revalidate();
  }

  /// The typed amount in piconero, or zero when the field is not a number.
  BigInt _amountUnits() {
    try {
      return decimalToBaseUnits(_amountController.text, _xmrDecimals);
    } on FormatException {
      return BigInt.zero;
    }
  }

  Future<void> _onAmountChanged() async {
    final wallet = appWalletOf(context);
    // Base units for the same reason as in `_validateForm`: `==` between two
    // differently-rounded doubles decided whether this is a sweep.
    final isFullBalance = _amountUnits() == wallet.unlockedBalanceBaseUnits;

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

    if (_amountError.isNotEmpty) {
      setState(() => _amountError = '');
    }
    await _revalidate();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final wallet = appWalletOf(context, listen: true);
    final fiatRate = context.watch<FiatRateModel>();
    final fiatSymbol = consts.currencySymbols[fiatRate.fiatCode] ?? '\$';
    final coinRate = fiatRate.rateFor('XMR');

    final amount = double.tryParse(_amountController.text) ?? 0;
    final amountFiat = coinRate != null ? amount * coinRate : 0.0;
    final available = wallet.unlockedBalance ?? 0;
    final xmr = xmrWallet(context);

    if (isDesktop) {
      return DesktopShell(
        active: DesktopNav.home,
        child: _desktopBody(context, i18n, fiatSymbol, coinRate, amountFiat, available),
      );
    }

    return SendView(
      labels: SendLabels(
        title: i18n.sendTitle,
        toLabel: i18n.sendToLabel,
        amount: i18n.amount,
        priorityHeading: i18n.sendPriorityHeading,
        networkFee: i18n.sendNetworkFee,
        sendButton: i18n.sendSendButton,
        cancel: i18n.cancel,
        pasteButton: i18n.sendPasteButton,
        scanButton: i18n.sendScanButton,
        contactsButton: i18n.sendContactsButton,
        maxButton: i18n.sendMaxButton,
        addressHint: i18n.address,
        priorityLabels: [i18n.sendPriorityLow, i18n.sendPriorityNormal, i18n.sendPriorityHigh],
      ),
      onBack: () => Navigator.of(context).pop(),
      addressController: _destinationAddressController,
      addressError: _destinationAddressError,
      openAliasResolving: _openAliasResolving > 0,
      onPaste: _pasteAddressFromClipboard,
      onScan: _scanQrCode,
      onPickContact: _showContactPicker,
      contactName: _selectedContact?.name,
      contactAddressShort: _selectedContact != null
          ? _shortenMiddle(_destinationAddressController.text, head: 8, tail: 10)
          : null,
      onClearContact: _clearSelectedContact,
      amountController: _amountController,
      amountError: _amountError,
      onMax: _setBalanceAsSendAmount,
      coinSymbol: 'XMR',
      amountFiatText: '≈ ${formatFiat(amountFiat, fiatSymbol)}',
      availableText: '${_amountText(available)} ${i18n.sendAvailableSuffix}',
      availableLeading: xmr != null
          ? CoinMark(coinSymbol: xmr.coinSymbol, iconAsset: xmr.iconAsset, size: 16)
          : const SizedBox(width: 16, height: 16),
      onAvailableTap: _setBalanceAsSendAmount,
      selectedPriority: _selectedPriority,
      onSelectPriority: _setPriority,
      feeValue: _feeValue(fiatSymbol, coinRate),
      onCancel: () => Navigator.pop(context),
      onSend: (_formValid && _openAliasResolving == 0 && !_isLoading) ? _send : null,
      sendLoading: _isLoading,
    );
  }

  // ----- Desktop two-column form (Monero-only: no from-card / asset picker) -----

  Widget _desktopBody(
    BuildContext context,
    AppLocalizations i18n,
    String fiatSymbol,
    double? coinRate,
    double amountFiat,
    double available,
  ) {
    final canSend = _formValid && _openAliasResolving == 0 && !_isLoading;
    return ListView(
      padding: const EdgeInsets.fromLTRB(44, 30, 44, 36),
      children: [
        DesktopBackLink(label: i18n.navigationBarWallet, onTap: () => Navigator.pop(context)),
        const SizedBox(height: 16),
        Text(i18n.sendTitle, style: desktopTitleStyle),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _dField(i18n.sendToLabel, _dToCard(i18n)),
                  if (_destinationAddressError.isNotEmpty) _dError(_destinationAddressError),
                  const SizedBox(height: 16),
                  _dField(i18n.amount, _dAmountCard(i18n, fiatSymbol, amountFiat, available)),
                  if (_amountError.isNotEmpty) _dError(_amountError),
                ],
              ),
            ),
            const SizedBox(width: 28),
            SizedBox(
              width: 316,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _dField(
                    i18n.sendPriorityHeading,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BrandSegmented(
                          labels: [
                            i18n.sendPriorityLow,
                            i18n.sendPriorityNormal,
                            i18n.sendPriorityHigh,
                          ],
                          selectedIndex: _selectedPriority,
                          onSelect: _setPriority,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              i18n.sendNetworkFee,
                              style: TextStyle(
                                fontFamily: 'Ubuntu',
                                fontSize: 12.5,
                                color: BrandColors.inkMuted,
                              ),
                            ),
                            _feeValue(fiatSymbol, coinRate),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  BrandButton(
                    label: i18n.sendSendButton,
                    loading: _isLoading,
                    onPressed: canSend ? _send : null,
                  ),
                  const SizedBox(height: 9),
                  BrandButton.ghost(label: i18n.cancel, onPressed: () => Navigator.pop(context)),
                  const SizedBox(height: 16),
                  Text(
                    i18n.sendIrreversibleNote,
                    style: TextStyle(
                      fontFamily: 'Ubuntu',
                      fontSize: 12,
                      height: 1.6,
                      color: BrandColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dField(String caption, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(caption.toUpperCase(), style: BrandText.section),
      ),
      const SizedBox(height: 8),
      child,
    ],
  );

  Widget _dError(String text) => Padding(
    padding: const EdgeInsets.only(top: 8, left: 2),
    child: Text(text, style: BrandText.caption.copyWith(color: BrandColors.error)),
  );

  Widget _dCard({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: BrandColors.card,
      border: Border.all(color: BrandColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    child: child,
  );

  Widget _dToCard(AppLocalizations i18n) {
    final contact = _selectedContact;
    return _dCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (contact != null)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: TextStyle(
                          fontFamily: 'Ubuntu',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: BrandColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _shortenMiddle(_destinationAddressController.text, head: 10, tail: 12),
                        style: TextStyle(
                          fontFamily: 'Ubuntu Mono',
                          fontSize: 12,
                          color: BrandColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: BrandColors.inkMuted),
                  onPressed: _clearSelectedContact,
                ),
              ],
            )
          else
            TextField(
              controller: _destinationAddressController,
              minLines: 1,
              maxLines: 2,
              style: TextStyle(
                fontFamily: 'Ubuntu Mono',
                fontSize: 13.5,
                height: 1.6,
                color: BrandColors.ink,
              ),
              decoration: InputDecoration.collapsed(
                hintText: i18n.address,
                hintStyle: TextStyle(
                  fontFamily: 'Ubuntu Mono',
                  fontSize: 13.5,
                  height: 1.6,
                  color: BrandColors.inkFaint,
                ),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              _dPill(Icons.content_paste, i18n.sendPasteButton, _pasteAddressFromClipboard),
              const SizedBox(width: 8),
              _dPill(Icons.people_outline, i18n.sendContactsButton, _showContactPicker),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dAmountCard(
    AppLocalizations i18n,
    String fiatSymbol,
    double amountFiat,
    double available,
  ) {
    return _dCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontFamily: 'Ubuntu Mono',
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: BrandColors.ink,
                  ),
                  decoration: InputDecoration.collapsed(
                    hintText: '0',
                    hintStyle: TextStyle(
                      fontFamily: 'Ubuntu Mono',
                      fontSize: 28,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: BrandColors.inkDisabled,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'XMR',
                style: TextStyle(
                  fontFamily: 'Ubuntu Mono',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.ink,
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: BrandColors.surfaceTinted,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: _setBalanceAsSendAmount,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    child: Text(
                      i18n.sendMaxButton,
                      style: TextStyle(
                        fontFamily: 'Ubuntu Mono',
                        fontSize: 10.5,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.primaryDeep,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '≈ ${formatFiat(amountFiat, fiatSymbol)}',
                style: TextStyle(
                  fontFamily: 'Ubuntu Mono',
                  fontSize: 12.5,
                  color: BrandColors.inkMuted,
                ),
              ),
              Text(
                '${_amountText(available)} ${i18n.sendAvailableSuffix}',
                style: TextStyle(
                  fontFamily: 'Ubuntu Mono',
                  fontSize: 12.5,
                  color: BrandColors.inkMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dPill(IconData icon, String label, VoidCallback onTap) => Material(
    color: BrandColors.surfaceSunken,
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: BrandColors.primaryDeep),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Ubuntu',
                fontSize: 12.5,
                height: 1,
                fontWeight: FontWeight.w500,
                color: BrandColors.primaryDeep,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _feeValue(String fiatSymbol, double? coinRate) {
    final feePiconero = (_fees != null && _fees!.length > _selectedPriority)
        ? _fees![_selectedPriority]
        : null;
    if (_isLoadingFees) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: BrandColors.primary),
      );
    }
    if (feePiconero == null) {
      return Text(
        '—',
        style: TextStyle(fontFamily: 'Ubuntu Mono', fontSize: 12, color: BrandColors.inkMuted),
      );
    }
    final fee = doubleAmountFromInt(feePiconero);
    final feeFiat = coinRate != null ? ' · ${formatFiat(fee * coinRate, fiatSymbol)}' : '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset('assets/icons/monero.svg', width: 13, height: 13),
        const SizedBox(width: 5),
        Text(
          '~${_amountText(fee)}$feeFiat',
          style: TextStyle(fontFamily: 'Ubuntu Mono', fontSize: 12, color: BrandColors.inkMuted),
        ),
      ],
    );
  }
}

/// Monero is decimal-12; cap the displayed amount for legibility.
String _amountText(double amount) => amount.toStringAsFixed(5);

/// Monero's decimal places. Matches the adapter's own constant; kept local so
/// this file does not reach into the adapter's privates.
const _xmrDecimals = 12;

/// `abcd…wxyz`: keeps [head] leading and [tail] trailing chars of a long
/// address, eliding the middle. Returns the string unchanged when short.
String _shortenMiddle(String value, {required int head, required int tail}) {
  if (value.length <= head + tail + 1) return value;
  return '${value.substring(0, head)}…${value.substring(value.length - tail)}';
}
