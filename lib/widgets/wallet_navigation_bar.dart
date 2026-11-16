import 'package:flutter/material.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/l10n/shared_strings.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

/// Brand bottom nav — flat icon+label tabs on the paper ground with a hairline
/// top border (copied from Spice's design). Skylight's destinations:
/// Wallet / History / Contacts / Settings.
class WalletNavigationBar extends StatelessWidget {
  final int selectedIndex;

  const WalletNavigationBar({super.key, required this.selectedIndex});

  static const _routes = ['/wallet_home', '/history', '/address_book', '/settings'];

  void _select(BuildContext context, int index) {
    if (index == selectedIndex || !context.mounted) return;
    // A touch calls this twice, on tap-down and again on release. The push on
    // tap-down leaves this screen's route no longer current, so the release
    // does nothing. Screen readers, Switch Access and the keyboard send only
    // the tap, which navigates.
    if (ModalRoute.isCurrentOf(context) != true) return;
    Navigator.pushNamed(context, _routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final items = [
      (Icons.account_balance_wallet_outlined, i18n.navigationBarWallet),
      (Icons.history, i18n.shared.navigationBarHistory),
      (Icons.people_outline, i18n.shared.addressBookTitle),
      (Icons.tune, i18n.shared.navigationBarSettings),
    ];

    return Hero(
      tag: 'main-navigation-bar',
      child: Material(
        color: BrandColors.paper,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: BrandColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 9, left: 4, right: 4, bottom: 4),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavTab(
                        icon: items[i].$1,
                        label: items[i].$2,
                        selected: i == selectedIndex,
                        onTap: () => _select(context, i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? BrandColors.primaryDeep : BrandColors.inkMuted;
    // One tab node, named by its label; the icon beside it says nothing more.
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      child: InkWell(
        // Navigate on touch-down, not release: a very light (or slightly rolling)
        // tap can drift past the tap recognizer's slop before the finger lifts
        // and get dropped. onTap navigates too, for assistive tech and the
        // keyboard, which send only a tap; after a touch-down it does nothing.
        onTapDown: (_) => onTap(),
        onTap: onTap,
        borderRadius: BorderRadius.circular(BrandRadii.tile),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 23, color: color),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
