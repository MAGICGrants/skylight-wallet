import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:monero/monero.dart' as monero;
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/contact_model.dart';
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
      builder: (context) => AlertDialog(
        title: Text(i18n.addressBookDeleteContact),
        content: Text(i18n.addressBookDeleteContactConfirmation(contact.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(i18n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Provider.of<ContactModel>(
                context,
                listen: false,
              ).deleteContact(contact.id);
              Navigator.of(context).pop();
            },
            child: Text(i18n.addressBookDelete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.addressBookTitle),
        actions: [
          IconButton(
            onPressed: _showAddContactDialog,
            icon: Icon(Icons.add),
            tooltip: i18n.addressBookAddContact,
          ),
        ],
      ),
      bottomNavigationBar: WalletNavigationBar(selectedIndex: 1),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
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
          ),
          Expanded(
            child: Consumer<ContactModel>(
              builder: (context, contactModel, child) {
                final filteredContacts = contactModel.searchContacts(
                  _searchQuery,
                );

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
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          SizedBox(height: 8),
                          Text(
                            i18n.addressBookNoContactsDescription,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
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

  const _ContactListItem({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  void _copyAddressToClipboard(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    Clipboard.setData(ClipboardData(text: contact.address));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(i18n.addressBookAddressCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

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
        title: Text(
          contact.name,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          contact.address,
          style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'copy':
                _copyAddressToClipboard(context);
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
                children: [
                  Icon(Icons.copy),
                  SizedBox(width: 8),
                  Text(i18n.addressBookCopyAddress),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text(i18n.addressBookEdit),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    i18n.addressBookDelete,
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _copyAddressToClipboard(context),
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
  final _addressController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.contact != null) {
      _nameController.text = widget.contact!.name;
      _addressController.text = widget.contact!.address;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final i18n = AppLocalizations.of(context)!;
    if (value == null || value.trim().isEmpty) {
      return i18n.fieldEmptyError;
    }
    return null;
  }

  String? _validateAddress(String? value) {
    final i18n = AppLocalizations.of(context)!;

    if (value == null || value.trim().isEmpty) {
      return i18n.fieldEmptyError;
    }

    // ignore: deprecated_member_use
    if (!monero.Wallet_addressValid(value.trim(), 0)) {
      return i18n.sendInvalidAddressError;
    }
    return null;
  }

  Future<void> _saveContact() async {
    final i18n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final contactModel = Provider.of<ContactModel>(context, listen: false);

      if (widget.contact == null) {
        await contactModel.addContact(
          _nameController.text.trim(),
          _addressController.text.trim(),
        );
      } else {
        await contactModel.updateContact(
          widget.contact!.id,
          _nameController.text.trim(),
          _addressController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(i18n.unknownError),
            backgroundColor: Colors.red,
          ),
        );
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

    return AlertDialog(
      title: Text(
        isEditing ? i18n.addressBookEditContact : i18n.addressBookAddContact,
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: i18n.addressBookContactName,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              validator: _validateName,
              textCapitalization: TextCapitalization.words,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: i18n.address,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              validator: _validateAddress,
              maxLines: 3,
            ),
          ],
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
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? i18n.addressBookUpdate : i18n.addressBookSave),
        ),
      ],
    );
  }
}
