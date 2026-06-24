import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/consts.dart' as consts;
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/widgets/loading_button.dart';
import 'package:skylight_wallet/models/contact_model.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/screens/confirm_send.dart';
import 'package:skylight_wallet/wallets/crypto_wallet.dart';
import 'package:skylight_wallet/wallets/wallet_manager.dart';
import 'package:skylight_wallet/widgets/coin_amount.dart';
import 'package:skylight_wallet/widgets/fiat_amount.dart';

class SendScreenArgs {
  final String coinSymbol;
  final String destinationAddress;
  final double? amount;

  SendScreenArgs({required this.coinSymbol, required this.destinationAddress, this.amount});
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

  CryptoWallet _wallet(BuildContext context) {
    final manager = Provider.of<WalletManager>(context, listen: false);
    final wallet = manager.getWallet(_coinSymbol);
    if (wallet == null) {
      throw StateError('No wallet for $_coinSymbol');
    }
    return wallet;
  }

  Future<String> _resolveAddressIfDomain(String value) async {
    final wallet = _wallet(context);
    if (!domainRegex.hasMatch(value)) return value;
    // All coins use the DNSSEC-over-Tor OpenAlias resolver (Monero included).
    // Empty result → caller shows the resolve error.
    if (wallet.openAliasAsset.isNotEmpty) {
      if (value == _resolveCacheInput) return _resolveCacheOutput; // avoid re-lookup
      final i18n = AppLocalizations.of(context)!;
      // Counter (not a bool): resolution runs from several call sites that can
      // overlap (validate, fee calc, send), so the spinner stays up until all
      // finish.
      if (mounted) setState(() => _openAliasResolving++);
      String resolved = '';
      String error = '';
      try {
        resolved = (await wallet.resolveOpenAliasAddress(value)) ?? '';
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
    }
  }

  void _pasteAddressFromClipboard() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);

    if (data != null) {
      _destinationAddressController.text = data.text ?? '';
    }
  }

  Future<void> _scanQrCode() async {
    final wallet = _wallet(context);
    final i18n = AppLocalizations.of(context)!;

    final result = await Navigator.pushNamed(context, '/scan_qr');

    if (result == null || result is! String) return;

    String address = '';
    double? amount;
    final uri = Uri.tryParse(result);

    if (uri != null && uri.scheme.toLowerCase() == wallet.coinSymbol.toLowerCase()) {
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

  void _showContactPicker() {
    showDialog(
      context: context,
      builder: (context) => _ContactPickerDialog(
        coinSymbol: _coinSymbol,
        onContactSelected: (contact) {
          final address = contact.addressFor(_coinSymbol);
          if (address == null) return;

          setState(() {
            _selectedContact = contact;
            _destinationAddressController.text = address;
          });
          Navigator.of(context).pop();
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
          _destinationAddressError = i18n.sendInvalidAddressError;
        });
      }
      return false;
    }

    if (destinationAddress.isEmpty) return false;

    if (amount > (wallet.unlockedBalance ?? 0)) {
      if (setErrors) {
        setState(() {
          _amountError = i18n.sendInsufficientBalanceError;
        });
      }
      return false;
    }

    return true;
  }

  Future<PendingTransaction?> _createTxForPriority(
    String destinationAddress,
    double amount,
    int priority,
  ) async {
    final wallet = _wallet(context);
    final maxRetries = 10;

    for (int i = 0; i < maxRetries; i++) {
      try {
        return await wallet.createTx(destinationAddress, amount, _isSweepAll, priority: priority);
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
    final amount = double.parse(_amountController.text);

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

        fees[idx] = await _createTxForPriority(destinationAddress, amount, idx + 1);

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
    final amount = double.parse(_amountController.text);
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
          amount,
          _isSweepAll,
          priority: _selectedPriority + 1,
        );
      }

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/confirm_send',
          arguments: ConfirmSendScreenArgs(
            coinSymbol: _coinSymbol,
            tx: tx,
            destinationAddress: destinationAddress,
            destinationOpenAlias: destinationOpenAlias,
            destinationContactName: _selectedContact?.name,
          ),
        );
      }
    } catch (error) {
      if (error.toString().contains('Insufficient gas funds')) {
        setState(() {
          _amountError = i18n.sendInsufficientGasError;
        });
      } else if (error.toString().contains('Unlocked funds too low')) {
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

  void _setBalanceAsSendAmount() {
    final wallet = _wallet(context);
    _amountController.text = (wallet.unlockedBalance ?? 0).toString();

    setState(() {
      _isSweepAll = true;
    });
  }

  void _showPrioritySelector(CryptoWallet wallet) {
    final i18n = AppLocalizations.of(context)!;
    final fiatRate = Provider.of<FiatRateModel>(context, listen: false);
    final fiatSymbol = consts.currencySymbols[fiatRate.fiatCode] ?? '\$';
    final coinRate = fiatRate.rateFor(wallet.coinSymbol, isTestnet: wallet.isTestnet);

    showModalBottomSheet(
      context: context,
      builder: (context) => ValueListenableBuilder<int>(
        valueListenable: _feeRevision,
        builder: (context, _, __) => SafeArea(
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i18n.sendTransactionPriority, style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: 20),
                _PriorityOption(
                  label: i18n.sendPriorityLow,
                  priority: 0,
                  fees: _fees,
                  isLoading: _feesInProgress,
                  wallet: wallet,
                  fiatSymbol: fiatSymbol,
                  fiatRate: coinRate,
                  isSelected: _selectedPriority == 0,
                  onTap: () {
                    setState(() {
                      _selectedPriority = 0;
                    });
                    Navigator.pop(context);
                  },
                ),
                SizedBox(height: 12),
                _PriorityOption(
                  label: i18n.sendPriorityNormal,
                  priority: 1,
                  fees: _fees,
                  isLoading: _feesInProgress,
                  wallet: wallet,
                  fiatSymbol: fiatSymbol,
                  fiatRate: coinRate,
                  isSelected: _selectedPriority == 1,
                  onTap: () {
                    setState(() {
                      _selectedPriority = 1;
                    });
                    Navigator.pop(context);
                  },
                ),
                SizedBox(height: 12),
                _PriorityOption(
                  label: i18n.sendPriorityHigh,
                  priority: 2,
                  fees: _fees,
                  isLoading: _feesInProgress,
                  wallet: wallet,
                  fiatSymbol: fiatSymbol,
                  fiatRate: coinRate,
                  isSelected: _selectedPriority == 2,
                  onTap: () {
                    setState(() {
                      _selectedPriority = 2;
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onAddressChanged() {
    // Input changed: invalidate the resolution cache + clear any stale error.
    _resolveCacheInput = '';
    _resolveCacheOutput = '';
    if (_destinationAddressError.isNotEmpty) {
      setState(() => _destinationAddressError = '');
    }

    final text = _destinationAddressController.text;
    final isOpenAliasDomain =
        domainRegex.hasMatch(text) && _wallet(context).openAliasAsset.isNotEmpty;

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

    _scheduleFeeCalculation();
  }

  void _scheduleFeeCalculation() {
    _feeDebounce?.cancel();
    _feeDebounce = Timer(Duration(milliseconds: 400), () {
      unawaited(_calculateFeesIfValid());
    });
  }

  Future<void> _calculateFeesIfValid() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final balance = _wallet(context).unlockedBalance ?? 0;

    if (amount == 0 || amount > balance) {
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
        appBar: AppBar(title: Text(i18n.sendTitle)),
        body: Center(child: Text('Unknown coin: $_coinSymbol')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(i18n.sendTitle)),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            constraints: BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 28,
              children: [
                Column(
                  spacing: 16,
                  children: [
                    if (_selectedContact == null)
                      TextField(
                        controller: _destinationAddressController,
                        focusNode: _addressFocusNode,
                        maxLines: null,
                        decoration: InputDecoration(
                          labelText: i18n.address,
                          border: OutlineInputBorder(),
                          errorText: _destinationAddressError != ''
                              ? _destinationAddressError
                              : null,
                          suffixIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
                          suffixIcon: Container(
                            margin: EdgeInsets.only(right: 14),
                            child: Row(
                              spacing: 16,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_openAliasResolving > 0)
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 1.8),
                                  ),
                                GestureDetector(
                                  onTap: _pasteAddressFromClipboard,
                                  child: Icon(Icons.paste),
                                ),
                                if (Platform.isAndroid || Platform.isIOS)
                                  GestureDetector(onTap: _scanQrCode, child: Icon(Icons.qr_code)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_selectedContact != null)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Text(
                                    _selectedContact!.name.isNotEmpty
                                        ? _selectedContact!.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedContact!.name,
                                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                                      ),
                                      Text(
                                        i18n.sendSelectedContact,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _clearSelectedContact,
                                  icon: Icon(Icons.close, size: 20),
                                  tooltip: i18n.sendClearSelectedContact,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+(\.\d*)?'))],
                      decoration: InputDecoration(
                        labelText: i18n.amount,
                        border: OutlineInputBorder(),
                        errorText: _amountError != '' ? _amountError : null,
                        suffixIcon: TextButton(
                          onPressed: _setBalanceAsSendAmount,
                          child: Text('Max'),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showPrioritySelector(wallet),
                      child: Container(
                        height: 40,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.speed, size: 18),
                            SizedBox(width: 8),
                            Text(
                              _selectedPriority == 0
                                  ? i18n.sendPriorityLow
                                  : _selectedPriority == 1
                                  ? i18n.sendPriorityNormal
                                  : i18n.sendPriorityHigh,
                              style: TextStyle(fontSize: 14),
                            ),
                            Text(
                              ' ${i18n.sendPriorityLabel}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Spacer(),
                            if (_isLoadingFees)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else if (_fees != null && _fees!.length > _selectedPriority)
                              () {
                                final selectedTx = _fees![_selectedPriority];
                                if (selectedTx != null) {
                                  return Row(
                                    spacing: 8,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        spacing: 4,
                                        children: [
                                          SvgPicture.asset(
                                            wallet.feeIconAsset,
                                            width: 14,
                                            height: 14,
                                          ),
                                          CoinAmount(
                                            amount: selectedTx.fee,
                                            decimals: wallet.feeDecimals,
                                            smallerDigits: wallet.smallerDigits,
                                            maxFontSize: 14,
                                          ),
                                        ],
                                      ),
                                      Icon(Icons.arrow_drop_down),
                                    ],
                                  );
                                } else {
                                  return Row(
                                    spacing: 8,
                                    children: [
                                      Text(
                                        i18n.sendInsufficientBalanceError,
                                        style: TextStyle(color: Colors.red, fontSize: 14),
                                      ),
                                      Icon(Icons.arrow_drop_down),
                                    ],
                                  );
                                }
                              }()
                            else
                              Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        if (_selectedContact == null)
                          TextButton.icon(
                            onPressed: _showContactPicker,
                            icon: Icon(Icons.contacts_outlined, size: 18),
                            label: Text(i18n.sendContactsButton),
                          ),
                        Spacer(),
                        GestureDetector(
                          onTap: _setBalanceAsSendAmount,
                          child: Row(
                            spacing: 6,
                            children: [
                              SvgPicture.asset(wallet.iconAsset, width: 18, height: 18),
                              CoinAmount(
                                amount: wallet.unlockedBalance ?? 0,
                                decimals: wallet.decimals,
                                smallerDigits: wallet.smallerDigits,
                                maxFontSize: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  spacing: 20,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n.cancel)),
                    LoadingButton(
                      isLoading: _isLoading,
                      onPressed: (_formValid && _openAliasResolving == 0) ? _send : null,
                      label: i18n.sendSendButton,
                      icon: Icons.arrow_outward_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactPickerDialog extends StatefulWidget {
  final String coinSymbol;
  final Function(Contact) onContactSelected;

  const _ContactPickerDialog({required this.coinSymbol, required this.onContactSelected});

  @override
  State<_ContactPickerDialog> createState() => _ContactPickerDialogState();
}

class _ContactPickerDialogState extends State<_ContactPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth.clamp(0.0, 500.0);

    return AlertDialog(
      constraints: BoxConstraints.tightFor(width: dialogWidth),
      insetPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: i18n.addressBookSearchHint,
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Consumer<ContactModel>(
                builder: (context, contactModel, child) {
                  final filteredContacts = contactModel.searchContacts(
                    _searchQuery,
                    coinSymbol: widget.coinSymbol,
                  );

                  if (filteredContacts.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? i18n.addressBookNoContactsForCoin(widget.coinSymbol)
                            : i18n.addressBookNoSearchResults,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = filteredContacts[index];
                      final address = contact.addressFor(widget.coinSymbol)!;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Text(
                            contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(contact.name, style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          address,
                          style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => widget.onContactSelected(contact),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n.cancel))],
    );
  }
}

class _PriorityOption extends StatelessWidget {
  final String label;
  final int priority;
  final List<PendingTransaction?>? fees;
  final bool isLoading;
  final CryptoWallet wallet;
  final String fiatSymbol;
  final double? fiatRate;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityOption({
    required this.label,
    required this.priority,
    required this.fees,
    required this.isLoading,
    required this.wallet,
    required this.fiatSymbol,
    required this.fiatRate,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final feeTx = fees?[priority];
    final fee = feeTx?.fee;
    final currentFiatRate = fiatRate;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            Spacer(),
            if (fee != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 4,
                    children: [
                      Text(
                        '${i18n.sendFeeLabel}:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SvgPicture.asset(wallet.feeIconAsset, width: 14, height: 14),
                      CoinAmount(
                        amount: fee,
                        decimals: wallet.feeDecimals,
                        smallerDigits: wallet.smallerDigits,
                        maxFontSize: 14,
                      ),
                    ],
                  ),
                  if (currentFiatRate != null && !wallet.isTestnet && !wallet.feeIsForeign)
                    FiatAmount(prefix: fiatSymbol, amount: fee * currentFiatRate, maxFontSize: 12),
                ],
              )
            else if (isLoading)
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else if (fees != null)
              Text(
                i18n.sendInsufficientBalanceError,
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
          ],
        ),
      ),
    );
  }
}
