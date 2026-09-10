import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/contact_model.dart';
import 'package:skylight_wallet/screens/send.dart';
import 'package:skylight_wallet/util/secure_clipboard.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';
import 'package:skylight_wallet/widgets/wallet_navigation_bar.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key});

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _expandedId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddContactDialog() => _showContactSheet(null);

  void _showEditContactDialog(Contact contact) => _showContactSheet(contact);

  void _showContactSheet(Contact? contact) {
    showBrandSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ContactSheet(contact: contact),
    );
  }

  void _showDeleteContactDialog(Contact contact) {
    final i18n = AppLocalizations.of(context)!;
    showBrandSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              Row(
                children: [
                  SheetIcon(
                    icon: Icons.delete_outline,
                    bg: BrandColors.errorBg,
                    color: BrandColors.error,
                  ),
                  const SizedBox(width: 11),
                  Text(i18n.addressBookDeleteContact, style: BrandText.sheetTitle),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                i18n.addressBookDeleteContactConfirmation(contact.name),
                style: BrandText.bodyMuted.copyWith(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 18),
              BrandButton(label: i18n.cancel, onPressed: () => Navigator.pop(sheetContext)),
              const SizedBox(height: 4),
              BrandButton.ghost(
                label: i18n.addressBookDelete,
                color: BrandColors.error,
                onPressed: () {
                  Provider.of<ContactModel>(context, listen: false).deleteContact(contact.id);
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: BrandColors.paper,
      bottomNavigationBar: const WalletNavigationBar(selectedIndex: 1),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: BrandScreenHeader(
                    center: Text(
                      i18n.addressBookTitle,
                      style: BrandText.appBar.copyWith(fontSize: 16),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SearchField(
                          controller: _searchController,
                          onChanged: (q) => setState(() => _searchQuery = q),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _showAddContactDialog,
                        child: Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: BrandColors.primary,
                            borderRadius: BorderRadius.circular(BrandRadii.field),
                          ),
                          child: const Icon(Icons.add, size: 24, color: BrandColors.onPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Consumer<ContactModel>(
                    builder: (context, contactModel, child) {
                      final contacts = contactModel.searchContacts(_searchQuery);
                      if (contacts.isEmpty) return _EmptyState(searching: _searchQuery.isNotEmpty);
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                        itemCount: contacts.length,
                        itemBuilder: (context, index) {
                          final contact = contacts[index];
                          final expanded = contact.id == _expandedId;
                          return _ContactTile(
                            contact: contact,
                            expanded: expanded,
                            onToggle: () =>
                                setState(() => _expandedId = expanded ? null : contact.id),
                            onEdit: () => _showEditContactDialog(contact),
                            onDelete: () => _showDeleteContactDialog(contact),
                            isLast: index == contacts.length - 1,
                          );
                        },
                      );
                    },
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

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: BrandColors.card,
        border: Border.all(color: BrandColors.border),
        borderRadius: BorderRadius.circular(BrandRadii.field),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: BrandColors.inkFaint),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 14, color: BrandColors.ink),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: i18n.addressBookSearchHint,
                hintStyle: TextStyle(fontSize: 14, color: BrandColors.inkFaint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool searching;
  const _EmptyState({required this.searching});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 56, color: BrandColors.inkDisabled),
            const SizedBox(height: 16),
            Text(
              searching ? i18n.addressBookNoSearchResults : i18n.addressBookNoContacts,
              textAlign: TextAlign.center,
              style: BrandText.body,
            ),
            if (!searching) ...[
              const SizedBox(height: 6),
              Text(
                i18n.addressBookNoContactsDescription,
                textAlign: TextAlign.center,
                style: BrandText.bodyMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A round monogram avatar (contact's first initial).
class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: BrandColors.primaryDeep, shape: BoxShape.circle),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: BrandColors.onPrimary,
        ),
      ),
    );
  }
}

/// Expandable contact: collapsed shows the monogram + name + chain; tapping
/// opens a card with the Monero address row (copy / send) and edit / delete.
class _ContactTile extends StatelessWidget {
  final Contact contact;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isLast;

  const _ContactTile({
    required this.contact,
    required this.expanded,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    if (!expanded) {
      return Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  _Avatar(name: contact.name),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: BrandColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          shortenMiddle(contact.address, head: 8, tail: 8),
                          style: TextStyle(
                            fontFamily: 'Ubuntu Mono',
                            fontSize: 11.5,
                            color: BrandColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down, size: 22, color: BrandColors.inkMuted),
                ],
              ),
            ),
          ),
          if (!isLast) Divider(height: 1, thickness: 1, color: BrandColors.surfaceTinted),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: BrandCard(
        radius: 20,
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 13),
                child: Row(
                  children: [
                    _Avatar(name: contact.name),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.name,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: BrandColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_up, size: 22, color: BrandColors.inkMuted),
                  ],
                ),
              ),
            ),
            _AddressRow(contact: contact),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 6, 15, 15),
              child: Row(
                children: [
                  Expanded(
                    child: BrandButton.secondary(
                      label: i18n.addressBookEdit,
                      dense: true,
                      onPressed: onEdit,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BrandButton.ghost(
                      label: i18n.addressBookDelete,
                      color: BrandColors.error,
                      dense: true,
                      onPressed: onDelete,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Monero address row inside an expanded contact — icon, name, address, and
/// copy / send actions.
class _AddressRow extends StatelessWidget {
  final Contact contact;
  const _AddressRow({required this.contact});

  void _copy(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    // Treat as sensitive (auto-cleared) like other address/key copies.
    SecureClipboard.copy(contact.address);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.addressCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: BrandColors.surfaceTinted)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              contact.address,
              style: TextStyle(
                fontFamily: 'Ubuntu Mono',
                fontSize: 12,
                height: 1.4,
                color: BrandColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _IconSquare(icon: Icons.copy_outlined, onTap: () => _copy(context)),
          const SizedBox(width: 8),
          BrandButton(
            label: i18n.homeSend,
            icon: Icons.north_east,
            dense: true,
            expand: false,
            onPressed: () => Navigator.pushNamed(
              context,
              '/send',
              arguments: SendScreenArgs(destinationAddress: contact.address, contact: contact),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconSquare extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconSquare({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BrandColors.surfaceSunken,
          border: Border.all(color: BrandColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: BrandColors.primaryDeep),
      ),
    );
  }
}

/// Add / edit a single-address contact — a name and one Monero address.
class _ContactSheet extends StatefulWidget {
  final Contact? contact;

  const _ContactSheet({required this.contact});

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  final _nameController = TextEditingController();
  // The address is set only via paste/scan (never typed), matching Spice.
  String? _address;
  bool _saving = false;
  String? _error;
  // Set when the last paste/scan wasn't a valid address; cleared on the next set.
  bool _invalidAddress = false;

  bool get _isEditing => widget.contact != null;

  @override
  void initState() {
    super.initState();
    if (widget.contact != null) {
      _nameController.text = widget.contact!.name;
      _address = widget.contact!.address;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Accepts a bare address or a `monero:<address>?...` URI; null if invalid.
  String? _extractAddress(String raw) {
    final value = raw.trim();
    final uri = Uri.tryParse(value);
    if (uri != null && uri.scheme.toLowerCase() == 'monero') {
      return appWalletOf(context).isAddressValid(uri.path) ? uri.path : null;
    }
    return appWalletOf(context).isAddressValid(value) ? value : null;
  }

  void _setAddress(String? raw) {
    final address = raw == null ? null : _extractAddress(raw);
    if (address == null) {
      // Inline under the card, not a snackbar — the sheet covers snackbars.
      setState(() => _invalidAddress = true);
      return;
    }
    setState(() {
      _address = address;
      _error = null;
      _invalidAddress = false;
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (mounted) _setAddress(data?.text);
  }

  Future<void> _scan() async {
    final result = await Navigator.pushNamed(context, '/scan_qr');
    if (mounted && result is String) _setAddress(result);
  }

  Future<void> _save() async {
    final i18n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final address = _address;
    if (name.isEmpty || address == null) {
      setState(() => _error = i18n.fieldEmptyError);
      return;
    }

    setState(() => _saving = true);
    try {
      final model = Provider.of<ContactModel>(context, listen: false);
      if (widget.contact == null) {
        await model.addContact(name, address);
      } else {
        await model.updateContact(widget.contact!.id, name, address);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.unknownError)));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.only(top: 8), child: SheetHandle()),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SheetIcon(
                          icon: _isEditing ? Icons.edit_outlined : Icons.person_outline,
                          bg: BrandColors.surfaceTinted,
                          color: BrandColors.primaryDeep,
                        ),
                        const SizedBox(width: 11),
                        Text(
                          _isEditing ? i18n.addressBookEditContact : i18n.addressBookAddContact,
                          style: BrandText.sheetTitle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _isEditing ? i18n.addressBookEditDescription : i18n.addressBookAddDescription,
                      style: BrandText.bodyMuted.copyWith(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        label: i18n.addressBookContactName,
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                      ),
                      _nameField(name),
                      const SizedBox(height: 16),
                      SectionHeader(
                        label: _addressHeaderLabel(i18n),
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                      ),
                      _addressEntry(),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!, style: BrandText.caption.copyWith(color: BrandColors.error)),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                child: Column(
                  children: [
                    BrandButton(
                      label: _isEditing ? i18n.addressBookUpdate : i18n.addressBookSave,
                      loading: _saving,
                      onPressed: (_saving || name.isEmpty || _address == null) ? null : _save,
                    ),
                    const SizedBox(height: 4),
                    BrandButton.ghost(
                      label: i18n.cancel,
                      color: BrandColors.inkMuted,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _addressHeaderLabel(AppLocalizations i18n) {
    final coinName = xmrWallet(context)?.blockchainName ?? 'Monero';
    final label = '$coinName ${i18n.address}';
    return _address == null ? '$label · ${i18n.restoreWalletNotSet}' : label;
  }

  Widget _nameField(String name) {
    final i18n = AppLocalizations.of(context)!;
    final filled = name.isNotEmpty;
    return BrandCard(
      borderColor: filled ? BrandColors.border : BrandColors.inputBorder,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? BrandColors.primaryDeep : BrandColors.surfaceTinted,
              shape: BoxShape.circle,
            ),
            child: filled
                ? Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: BrandColors.onPrimary,
                    ),
                  )
                : Icon(Icons.person_outline, size: 17, color: BrandColors.inkDisabled),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.words,
              style: TextStyle(fontSize: 14.5, height: 1.3, color: BrandColors.ink),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: i18n.addressBookNameHint,
                hintStyle: TextStyle(fontSize: 14.5, color: BrandColors.inkFaint),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressEntry() {
    final i18n = AppLocalizations.of(context)!;
    final wallet = xmrWallet(context);
    final coinName = wallet?.blockchainName ?? 'Monero';
    final tile = wallet != null
        ? CoinMark(coinSymbol: wallet.coinSymbol, iconAsset: wallet.iconAsset, size: 30)
        : const SizedBox(width: 30, height: 30);
    final address = _address;

    if (address != null) {
      return BrandCard(
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(
          children: [
            tile,
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coinName,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: BrandColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    shortenMiddle(address, head: 9, tail: 9),
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
              onTap: () => setState(() {
                _address = null;
                _invalidAddress = false;
              }),
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: BrandColors.surfaceTinted, shape: BoxShape.circle),
                child: Icon(Icons.close, size: 13, color: BrandColors.inkMuted),
              ),
            ),
          ],
        ),
      );
    }

    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(
        color: _invalidAddress ? BrandColors.error : BrandColors.borderStrong,
        radius: 14,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: BrandColors.surfaceSunken,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                tile,
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    coinName,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: BrandColors.inkFaint,
                    ),
                  ),
                ),
                MiniActionButton(
                  bordered: true,
                  color: BrandColors.card,
                  icon: Icons.content_paste_outlined,
                  label: i18n.sendPasteButton,
                  onTap: _paste,
                ),
                if (Platform.isAndroid || Platform.isIOS) ...[
                  const SizedBox(width: 7),
                  MiniActionButton(
                    bordered: true,
                    color: BrandColors.card,
                    icon: Icons.qr_code_scanner,
                    label: i18n.sendScanButton,
                    onTap: _scan,
                  ),
                ],
              ],
            ),
            if (_invalidAddress) ...[
              const SizedBox(height: 8),
              Text(
                i18n.sendInvalidAddressError,
                style: BrandText.caption.copyWith(color: BrandColors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Draws a dashed rounded-rectangle outline (used for the not-yet-set address
/// card). Flutter's [Border] has no dashed style, so we stroke it by hand.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  static const _dash = 5.0;
  static const _gap = 4.0;
  static const _strokeWidth = 1.3;

  _DashedBorderPainter({required this.color, this.radius = 14});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dash;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0.0, metric.length)), paint);
        distance = next + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color || old.radius != radius;
}
