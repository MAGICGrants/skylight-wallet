import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
// ignore: implementation_imports
import 'package:monero/src/monero.dart';
import 'package:skylight_wallet/consts.dart' as consts;
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/screens/confirm_send.dart';
import 'package:skylight_wallet/util/formatting.dart';
import 'package:skylight_wallet/widgets/fiat_amount.dart';
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

final domainRegex = RegExp(r'^(?!-)[A-Za-z0-9-]{1,63}(?<!-)(\.[A-Za-z]{2,})+$');

class _SendScreenState extends State<SendScreen> {
  bool _isLoading = false;
  bool _isLoadingFees = false;
  final _destinationAddressController = TextEditingController(text: '');
  final _amountController = TextEditingController(text: '');
  bool _isSweepAll = false;
  Contact? _selectedContact;
  List<MoneroPendingTransaction?>? _fees;
  int _selectedPriority = 1; // 0=Low, 1=Normal, 2=High
  int _feeCalculationCounter = 0; // Track the latest fee calculation request
  String _lastFeeFetchKey = '';

  String _destinationAddressError = '';
  String _amountError = '';

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

    _loadFormFromArgs();
    _destinationAddressController.addListener(_onAddressChanged);
    _amountController.addListener(_onAmountChanged);
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(i18n.sendInvalidAddressError)),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(i18n.sendInvalidAddressError)),
        );
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
    final wallet = Provider.of<WalletModel>(context, listen: false);
    final unresolvedDestinationAddress = _destinationAddressController.text;
    String destinationAddress = '';

    if (domainRegex.hasMatch(unresolvedDestinationAddress)) {
      destinationAddress = await wallet.resolveOpenAlias(unresolvedDestinationAddress);
    } else {
      destinationAddress = unresolvedDestinationAddress;
    }

    return destinationAddress;
  }

  Future<bool> _validateForm({bool setErrors = true}) async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final unresolvedDestinationAddress = _destinationAddressController.text;
    String destinationAddress = '';

    if (amount == 0) {
      return false;
    }

    final wallet = Provider.of<WalletModel>(context, listen: false);
    final i18n = AppLocalizations.of(context)!;

    if (domainRegex.hasMatch(unresolvedDestinationAddress)) {
      // check for openalias
      destinationAddress = await wallet.resolveOpenAlias(unresolvedDestinationAddress);

      if (destinationAddress == '') {
        if (setErrors) {
          setState(() {
            _destinationAddressError = i18n.sendOpenAliasResolveError;
          });
        }
        return false;
      }
    } else if (wallet.w2Wallet!.addressValid(unresolvedDestinationAddress, 0)) {
      // check for address
      destinationAddress = unresolvedDestinationAddress;
    } else {
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

  Future<MoneroPendingTransaction?> _createTxForPriority(
    String destinationAddress,
    double amount,
    int priority,
  ) async {
    final wallet = Provider.of<WalletModel>(context, listen: false);
    const maxRetries = 10;

    for (int i = 0; i < maxRetries; i++) {
      try {
        final tx = await wallet.createTx(
          destinationAddress,
          amount,
          _isSweepAll,
          priority: priority,
        );
        return tx;
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

    // Increment counter to mark this as the latest request
    _feeCalculationCounter++;
    final currentRequest = _feeCalculationCounter;

    setState(() {
      _isLoadingFees = true;
      _fees = null;
    });

    final destinationAddress = await _resolveDestinationAddress();
    final amount = double.parse(_amountController.text);

    try {
      final txs = await Future.wait([
        _createTxForPriority(destinationAddress, amount, 1),
        _createTxForPriority(destinationAddress, amount, 2),
        _createTxForPriority(destinationAddress, amount, 3),
      ]);

      // Only update state if this is still the latest request
      if (currentRequest == _feeCalculationCounter && mounted) {
        setState(() {
          _fees = txs;
          _isLoadingFees = false;
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

    // Resolve openalias if it is a domain
    if (domainRegex.hasMatch(destinationAddressUnresolved)) {
      destinationAddress = await wallet.resolveOpenAlias(destinationAddressUnresolved);
      destinationOpenAlias = destinationAddressUnresolved;
    } else {
      destinationAddress = destinationAddressUnresolved;
    }

    try {
      MoneroPendingTransaction tx;

      // Check if we can reuse a cached transaction
      final currentFeeFetchKey = '${_destinationAddressController.text}-${_amountController.text}';
      final cachedTx = _fees != null && _fees!.length > _selectedPriority
          ? _fees![_selectedPriority]
          : null;

      if (currentFeeFetchKey == _lastFeeFetchKey && cachedTx != null) {
        tx = cachedTx;
      } else {
        // Create a new transaction if cached one is not available
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
            tx: tx,
            destinationAddress: destinationAddress,
            destinationOpenAlias: destinationOpenAlias,
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
                tx: _fees != null && _fees!.isNotEmpty ? _fees![0] : null,
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
                tx: _fees != null && _fees!.length > 1 ? _fees![1] : null,
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
                tx: _fees != null && _fees!.length > 2 ? _fees![2] : null,
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

  Future<void> _onAddressChanged() async {
    if (await _validateForm(setErrors: false)) {
      _calculateFees();
    }
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

    if (await _validateForm(setErrors: false)) {
      _calculateFees();
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final wallet = context.watch<WalletModel>();
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(i18n.sendTitle)),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            constraints: BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 20,
              children: [
                if (_selectedContact == null)
                  TextField(
                    controller: _destinationAddressController,
                    maxLines: null,
                    decoration: InputDecoration(
                      labelText: i18n.address,
                      border: OutlineInputBorder(),
                      errorText: _destinationAddressError != '' ? _destinationAddressError : null,
                      suffixIcon: Container(
                        margin: EdgeInsets.only(right: 14),
                        child: Row(
                          spacing: 16,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _pasteAddressFromClipboard,
                              child: Icon(Icons.paste),
                            ),
                            if (Platform.isAndroid || Platform.isIOS)
                              GestureDetector(
                                onTap: _scanQrCode,
                                child: Icon(Icons.qr_code),
                              ),
                            GestureDetector(
                              onTap: _showContactPicker,
                              child: Icon(Icons.contacts_outlined),
                            ),
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
                    suffixIcon: TextButton(onPressed: _setBalanceAsSendAmount, child: Text('Max')),
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
                                        'assets/icons/monero.svg',
                                        width: 14,
                                        height: 14,
                                      ),
                                      MoneroAmount(
                                        amount: doubleAmountFromInt(selectedTx.fee()),
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
                    Spacer(),
                    GestureDetector(
                      onTap: _setBalanceAsSendAmount,
                      child: Row(
                        spacing: 6,
                        children: [
                          Text(
                            '${i18n.sendBalanceLabel}:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SvgPicture.asset('assets/icons/monero.svg', width: 18, height: 18),
                          MoneroAmount(amount: wallet.unlockedBalance ?? 0, maxFontSize: 18),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  spacing: 20,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n.cancel)),
                    FilledButton.icon(
                      onPressed: _send,
                      icon: !_isLoading
                          ? Icon(Icons.arrow_outward_rounded)
                          : SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDarkTheme
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Colors.white,
                              ),
                            ),
                      label: Text(i18n.sendSendButton),
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
  final MoneroPendingTransaction? tx;
  final String fiatSymbol;
  final double? fiatRate;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityOption({
    required this.label,
    required this.priority,
    required this.tx,
    required this.fiatSymbol,
    required this.fiatRate,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final currentTx = tx;
    final fee = currentTx != null ? doubleAmountFromInt(currentTx.fee()) : null;
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
                      MoneroAmount(amount: fee, maxFontSize: 14),
                    ],
                  ),
                  if (currentFiatRate != null)
                    FiatAmount(prefix: fiatSymbol, amount: fee * currentFiatRate, maxFontSize: 12),
                ],
              )
            else
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
