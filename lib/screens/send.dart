import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/screens/confirm_send.dart';
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

class _SendScreenState extends State<SendScreen> {
  bool _isLoading = false;
  final _destinationAddressController = TextEditingController(text: '');
  final _amountController = TextEditingController(text: '');
  bool _isSweepAll = false;
  Contact? _selectedContact;

  String _destinationAddressError = '';
  String _amountError = '';

  @override
  void dispose() {
    _destinationAddressController.removeListener(_onAddressChanged);
    _destinationAddressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _loadFormFromArgs();
    _destinationAddressController.addListener(_onAddressChanged);
  }

  void _onAddressChanged() {
    // Clear selected contact if user manually types in address field
    if (_selectedContact != null &&
        _destinationAddressController.text != _selectedContact!.address) {
      setState(() {
        _selectedContact = null;
      });
    }
  }

  void _loadFormFromArgs() {
    final args = ModalRoute.of(context)!.settings.arguments as SendScreenArgs?;

    if (args != null) {
      _destinationAddressController.text = args.destinationAddress;
      _amountController.text = args.amount != null
          ? args.amount.toString()
          : '';
    }
  }

  void _pasteAddressFromClipboard() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);

    if (data != null) {
      _destinationAddressController.text = data.text ?? '';
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

  Future<void> _send() async {
    final amount = double.parse(_amountController.text);

    final i18n = AppLocalizations.of(context)!;

    setState(() {
      _isLoading = true;
      _destinationAddressError = '';
      _amountError = '';
    });

    final unresolvedDestinationAddress = _destinationAddressController.text;
    String? destinationOpenAlias;
    String destinationAddress = '';

    final wallet = Provider.of<WalletModel>(context, listen: false);
    final domainRegex = RegExp(
      r'^(?!-)[A-Za-z0-9-]{1,63}(?<!-)(\.[A-Za-z]{2,})+$',
    );

    if (domainRegex.hasMatch(unresolvedDestinationAddress)) {
      // check for openalias
      destinationAddress = wallet.resolveOpenAlias(
        unresolvedDestinationAddress,
      );

      if (destinationAddress == '') {
        setState(() {
          _destinationAddressError = i18n.sendOpenAliasResolveError;
          _isLoading = false;
        });
        return;
      }

      destinationOpenAlias = unresolvedDestinationAddress;
    } else if (wallet.w2Wallet!.addressValid(unresolvedDestinationAddress, 0)) {
      // check for address
      destinationAddress = unresolvedDestinationAddress;
    } else {
      setState(() {
        _destinationAddressError = i18n.sendInvalidAddressError;
        _isLoading = false;
      });
      return;
    }

    if (amount > (wallet.unlockedBalance ?? 0)) {
      setState(() {
        _amountError = i18n.sendInsufficientBalanceError;
        _isLoading = false;
      });
      return;
    }

    try {
      final tx = await wallet.createTx(destinationAddress, amount, _isSweepAll);

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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(i18n.unknownError)));
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

  void _onSendAmountChanged(double amount) {
    final wallet = Provider.of<WalletModel>(context, listen: false);

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
                    errorText: _destinationAddressError != ''
                        ? _destinationAddressError
                        : null,
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
                          GestureDetector(
                            onTap: () =>
                                Navigator.pushNamed(context, '/scan_qr'),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  i18n.sendSelectedContact,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
              Column(
                spacing: 10,
                children: [
                  TextField(
                    controller: _amountController,
                    onChanged: (value) =>
                        _onSendAmountChanged(double.parse(value)),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+(\.\d*)?'),
                      ),
                    ],
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
                  Row(
                    children: [
                      Spacer(),
                      GestureDetector(
                        onTap: _setBalanceAsSendAmount,
                        child: Row(
                          spacing: 6,
                          children: [
                            SvgPicture.asset(
                              'assets/icons/monero.svg',
                              width: 18,
                              height: 18,
                            ),
                            MoneroAmount(
                              amount: wallet.unlockedBalance ?? 0,
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
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(i18n.cancel),
                  ),
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

    return AlertDialog(
      title: Text(i18n.sendSelectFromAddressBook),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Consumer<ContactModel>(
                builder: (context, contactModel, child) {
                  final filteredContacts = contactModel.searchContacts(
                    _searchQuery,
                  );

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
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: Text(
                            contact.name.isNotEmpty
                                ? contact.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          contact.name,
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          contact.address,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(i18n.cancel),
        ),
      ],
    );
  }
}
