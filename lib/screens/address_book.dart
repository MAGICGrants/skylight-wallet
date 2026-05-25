import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/contact_model.dart';
import 'package:skylight_wallet/wallets/crypto_wallet.dart';
import 'package:skylight_wallet/wallets/wallet_manager.dart';
import 'package:skylight_wallet/widgets/wallet_navigation_bar.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key});

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
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

  void _showAddContactDialog() {
    showDialog(context: context, builder: (context) => _ContactDialog());
  }

  void _showEditContactDialog(Contact contact) {
    showDialog(
      context: context,
      builder: (context) => _ContactDialog(contact: contact),
    );
  }

  void _showDeleteContactDialog(Contact contact) {
    final i18n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth.clamp(0.0, 400.0);

        return AlertDialog(
          constraints: BoxConstraints.tightFor(width: dialogWidth),
          insetPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          title: Text(i18n.addressBookDeleteContact),
          content: Text(i18n.addressBookDeleteContactConfirmation(contact.name)),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n.cancel)),
            FilledButton(
              onPressed: () {
                Provider.of<ContactModel>(context, listen: false).deleteContact(contact.id);
                Navigator.of(context).pop();
              },
              child: Text(i18n.addressBookDelete),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(i18n.addressBookTitle)),
      bottomNavigationBar: WalletNavigationBar(selectedIndex: 1),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: i18n.addressBookSearchHint,
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(onPressed: _showAddContactDialog, icon: Icon(Icons.add)),
              ],
            ),
          ),
          Expanded(
            child: Consumer<ContactModel>(
              builder: (context, contactModel, child) {
                final filteredContacts = contactModel.searchContacts(_searchQuery);

                if (filteredContacts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.contacts_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? i18n.addressBookNoContacts
                              : i18n.addressBookNoSearchResults,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          SizedBox(height: 8),
                          Text(
                            i18n.addressBookNoContactsDescription,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredContacts.length,
                  itemBuilder: (context, index) {
                    final contact = filteredContacts[index];
                    return _ContactListItem(
                      contact: contact,
                      onEdit: () => _showEditContactDialog(contact),
                      onDelete: () => _showDeleteContactDialog(contact),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactListItem extends StatelessWidget {
  final Contact contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactListItem({required this.contact, required this.onEdit, required this.onDelete});

  void _copyAddressesToClipboard(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    Clipboard.setData(ClipboardData(text: contact.addressesForClipboard()));

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.addressCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final sortedEntries = contact.addresses.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in sortedEntries)
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${entry.key}: ',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      TextSpan(
                        text: entry.value,
                        style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        isThreeLine: sortedEntries.length > 1,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'copy':
                _copyAddressesToClipboard(context);
                break;
              case 'edit':
                onEdit();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'copy',
              child: Row(
                children: [Icon(Icons.copy), SizedBox(width: 8), Text(i18n.addressBookCopyAddress)],
              ),
            ),
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [Icon(Icons.edit), SizedBox(width: 8), Text(i18n.addressBookEdit)],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text(i18n.addressBookDelete, style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _copyAddressesToClipboard(context),
      ),
    );
  }
}

class _ContactDialog extends StatefulWidget {
  final Contact? contact;

  const _ContactDialog({this.contact});

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final Map<String, TextEditingController> _addressControllers = {};
  bool _isLoading = false;
  bool _controllersReady = false;
  String? _addressesError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controllersReady) return;
    _controllersReady = true;

    if (widget.contact != null) {
      _nameController.text = widget.contact!.name;
    }

    final wallets = context.read<WalletManager>().allWallets;
    for (final wallet in wallets) {
      _addressControllers[wallet.coinSymbol] = TextEditingController(
        text: widget.contact?.addressFor(wallet.coinSymbol) ?? '',
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final controller in _addressControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validateName(String? value) {
    final i18n = AppLocalizations.of(context)!;
    if (value == null || value.trim().isEmpty) {
      return i18n.fieldEmptyError;
    }
    return null;
  }

  String? _validateAddress(String? value, CryptoWallet wallet) {
    final i18n = AppLocalizations.of(context)!;
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    if (!wallet.isAddressValid(trimmed)) {
      return i18n.sendInvalidAddressError;
    }
    return null;
  }

  Map<String, String> _collectAddresses() {
    return {
      for (final entry in _addressControllers.entries)
        if (entry.value.text.trim().isNotEmpty) entry.key: entry.value.text.trim(),
    };
  }

  Future<void> _saveContact() async {
    final i18n = AppLocalizations.of(context)!;
    setState(() => _addressesError = null);

    if (!_formKey.currentState!.validate()) return;

    final addresses = _collectAddresses();
    if (addresses.isEmpty) {
      setState(() => _addressesError = i18n.addressBookAtLeastOneAddressError);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final contactModel = Provider.of<ContactModel>(context, listen: false);

      if (widget.contact == null) {
        await contactModel.addContact(_nameController.text.trim(), addresses);
      } else {
        await contactModel.updateContact(widget.contact!.id, _nameController.text.trim(), addresses);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(i18n.unknownError), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final isEditing = widget.contact != null;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final wallets = context.watch<WalletManager>().allWallets;

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth.clamp(0.0, 400.0);

    return AlertDialog(
      constraints: BoxConstraints.tightFor(width: dialogWidth),
      insetPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      title: Text(isEditing ? i18n.addressBookEditContact : i18n.addressBookAddContact),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: i18n.addressBookContactName,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                validator: _validateName,
                textCapitalization: TextCapitalization.words,
              ),
              SizedBox(height: 16),
              for (final wallet in wallets) ...[
                TextFormField(
                  controller: _addressControllers[wallet.coinSymbol],
                  decoration: InputDecoration(
                    labelText: '${wallet.coinName} (${wallet.coinSymbol})',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  validator: (value) => _validateAddress(value, wallet),
                  maxLines: 2,
                ),
                SizedBox(height: 12),
              ],
              if (_addressesError != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _addressesError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(i18n.cancel),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _saveContact,
          child: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDarkTheme ? Theme.of(context).colorScheme.onPrimary : Colors.white,
                  ),
                )
              : Text(isEditing ? i18n.addressBookUpdate : i18n.addressBookSave),
        ),
      ],
    );
  }
}
