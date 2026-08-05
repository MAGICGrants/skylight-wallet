import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:skylight_wallet/consts.dart' as consts;
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/screens/confirm_send.dart';
import 'package:skylight_wallet/util/formatting.dart';
import 'package:skylight_wallet/widgets/fiat_amount.dart';
import 'package:skylight_wallet/widgets/loading_button.dart';
import 'package:skylight_wallet/widgets/monero_amount.dart';
import 'package:skylight_wallet/models/wallet_model.dart';
import 'package:skylight_wallet/models/contact_model.dart';

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

    // Run once. didChangeDependencies fires on every WalletModel notify (via
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
    final wallet = Provider.of<WalletModel>(context, listen: false);
    final i18n = AppLocalizations.of(context)!;

    final result = await Navigator.pushNamed(context, '/scan_qr');

    if (result == null || result is! String) return;

    String address = '';
    double? amount;
    final uri = Uri.tryParse(result);

    if (uri != null && uri.scheme == 'monero') {
      if (!wallet.w2Wallet!.addressValid(uri.path, 0)) {
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
    } else if (wallet.w2Wallet!.addressValid(result, 0)) {
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
        onContactSelected: (contact) {
          setState(() {
            _selectedContact = contact;
            _destinationAddressController.text = contact.address;
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

    final wallet = Provider.of<WalletModel>(context, listen: false);
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

    final wallet = Provider.of<WalletModel>(context, listen: false);
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
    } else if (!wallet.w2Wallet!.addressValid(unresolvedDestinationAddress, 0)) {
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
    final wallet = Provider.of<WalletModel>(context, listen: false);

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
    final wallet = Provider.of<WalletModel>(context, listen: false);
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
        Navigator.pushNamed(
          context,
          '/confirm_send',
          arguments: ConfirmSendScreenArgs(
            tx: tx,
            destinationAddress: destinationAddress,
            destinationOpenAlias: destinationOpenAlias,
            destinationOpenAliasName: destinationOpenAliasName,
            destinationContactName: _selectedContact?.name,
          ),
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

  void _setBalanceAsSendAmount() {
    final wallet = Provider.of<WalletModel>(context, listen: false);
    _amountController.text = (wallet.unlockedBalance ?? 0).toString();

    setState(() {
      _isSweepAll = true;
    });
  }

  void _showPrioritySelector() {
    final i18n = AppLocalizations.of(context)!;
    final fiatRate = Provider.of<FiatRateModel>(context, listen: false);
    final fiatSymbol = consts.currencySymbols[fiatRate.fiatCode] ?? '\$';

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
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
                fiatSymbol: fiatSymbol,
                fiatRate: fiatRate.rate,
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
                fiatSymbol: fiatSymbol,
                fiatRate: fiatRate.rate,
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
                fiatSymbol: fiatSymbol,
                fiatRate: fiatRate.rate,
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
    );
  }

  /// Re-runs validation (without surfacing errors) and updates the send-button
  /// gate. Kicks off fee calculation when the form is valid.
  Future<void> _revalidate() async {
    final valid = await _validateForm(setErrors: false);
    if (mounted) setState(() => _formValid = valid);
    if (valid) _calculateFees();
  }

  Future<void> _onAddressChanged() async {
    await _revalidate();
  }

  Future<void> _onAmountChanged() async {
    final wallet = Provider.of<WalletModel>(context, listen: false);
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

    await _revalidate();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final wallet = context.watch<WalletModel>();

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
                      onTap: _showPrioritySelector,
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
                                final fee = _fees![_selectedPriority];
                                if (fee != null) {
                                  return Row(
                                    spacing: 8,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        spacing: 4,
                                        children: [
                                          SvgPicture.asset(
                                            'assets/icons/monero.svg',
                                            width: 14,
                                            height: 14,
                                          ),
                                          MoneroAmount(
                                            amount: doubleAmountFromInt(fee),
                                            maxFontSize: 14,
                                            prefix: '~',
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
                              SvgPicture.asset('assets/icons/monero.svg', width: 18, height: 18),
                              MoneroAmount(amount: wallet.unlockedBalance ?? 0, maxFontSize: 18),
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
                      icon: Icons.arrow_outward_rounded,
                      label: i18n.sendSendButton,
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
  final Function(Contact) onContactSelected;

  const _ContactPickerDialog({required this.onContactSelected});

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
                  final filteredContacts = contactModel.searchContacts(_searchQuery);

                  if (filteredContacts.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? i18n.addressBookNoContacts
                            : i18n.addressBookNoSearchResults,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = filteredContacts[index];
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
                          contact.address,
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
  final List<int?>? fees;
  final String fiatSymbol;
  final double? fiatRate;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityOption({
    required this.label,
    required this.priority,
    required this.fees,
    required this.fiatSymbol,
    required this.fiatRate,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final feePiconero = fees?[priority];
    final fee = feePiconero != null ? doubleAmountFromInt(feePiconero) : null;
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
                      SvgPicture.asset('assets/icons/monero.svg', width: 14, height: 14),
                      MoneroAmount(amount: fee, maxFontSize: 14, prefix: '~'),
                    ],
                  ),
                  if (currentFiatRate != null)
                    FiatAmount(prefix: fiatSymbol, amount: fee * currentFiatRate, maxFontSize: 12),
                ],
              )
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
