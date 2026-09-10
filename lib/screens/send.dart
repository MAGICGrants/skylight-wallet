import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/consts.dart' as consts;
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/app_wallet.dart';
import 'package:skylight_wallet/models/contact_model.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/models/wallet_types.dart';
import 'package:skylight_wallet/util/formatting.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

class SendScreenArgs {
  String destinationAddress;
  double? amount;

  SendScreenArgs({required this.destinationAddress, this.amount});
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
      _amountController.text = args.amount != null ? args.amount.toString() : '';
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
    double? amount;
    final uri = Uri.tryParse(result);

    if (uri != null && uri.scheme == 'monero') {
      if (!wallet.isAddressValid(uri.path)) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(i18n.sendInvalidAddressError)));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(i18n.sendInvalidAddressError)));
      }
      return;
    }

    _destinationAddressController.text = address;
    if (amount != null) {
      _amountController.text = amount.toString();
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
      headerIcon: SizedBox(
        width: 34,
        height: 34,
        child: SvgPicture.asset('assets/icons/monero.svg', width: 34, height: 34),
      ),
      // Skylight contacts hold a single Monero address, so every one is
      // selectable.
      search: (query) => [
        for (final c in contactModel.searchContacts(query))
          ContactPickerEntry<Contact>(
            value: c,
            name: c.name,
            addressShort: _shortenMiddle(c.address, head: 8, tail: 10),
          ),
      ],
    );

    if (contact == null || !mounted) return;
    setState(() {
      _selectedContact = contact;
      _destinationAddressController.text = contact.address;
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

    if (amount > (wallet.unlockedBalance ?? 0)) {
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
    final amount = double.parse(amountText);

    try {
      // Estimate the fee per priority natively (no full tx build).
      final fees = await Future.wait([
        wallet.estimateFee(destinationAddress, amount, priority: 1, amountText: amountText),
        wallet.estimateFee(destinationAddress, amount, priority: 2, amountText: amountText),
        wallet.estimateFee(destinationAddress, amount, priority: 3, amountText: amountText),
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
      // Only update state if this is still the latest request
      if (currentRequest == _feeCalculationCounter && mounted) {
        setState(() {
          _isLoadingFees = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(i18n.sendFailedToGetFeesError)));
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
    final amount = double.parse(_amountController.text);
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
        amount,
        _isSweepAll,
        priority: _selectedPriority + 1,
        amountText: _amountController.text,
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
        if (wallet.unlockedBalance! > amount) {
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
      rethrow;
    } catch (error) {
      log(LogLevel.error, error.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.unknownError)));
      }
      rethrow;
    }
  }

  void _setBalanceAsSendAmount() {
    final wallet = appWalletOf(context);
    _amountController.text = (wallet.unlockedBalance ?? 0).toString();

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

  Future<void> _onAmountChanged() async {
    final wallet = appWalletOf(context);
    final amount = double.tryParse(_amountController.text) ?? 0;

    if (amount == wallet.unlockedBalance! && !_isSweepAll) {
      setState(() {
        _isSweepAll = true;
      });
    }

    if (amount != wallet.unlockedBalance! && _isSweepAll) {
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

/// `abcd…wxyz`: keeps [head] leading and [tail] trailing chars of a long
/// address, eliding the middle. Returns the string unchanged when short.
String _shortenMiddle(String value, {required int head, required int tail}) {
  if (value.length <= head + tail + 1) return value;
  return '${value.substring(0, head)}…${value.substring(value.length - tail)}';
}
