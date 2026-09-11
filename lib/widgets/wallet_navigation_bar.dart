import 'package:flutter/material.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

/// Brand bottom nav — flat icon+label tabs on the paper ground with a hairline
/// top border (copied from Spice's design). Skylight's destinations:
/// Wallet / Contacts / Settings.
class WalletNavigationBar extends StatelessWidget {
  final int selectedIndex;

  const WalletNavigationBar({super.key, required this.selectedIndex});

  static const _routes = ['/wallet_home', '/address_book', '/settings'];

  void _select(BuildContext context, int index) {
    if (index == selectedIndex) return;
    Navigator.pushNamed(context, _routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final items = [
      (Icons.account_balance_wallet_outlined, i18n.navigationBarWallet),
      (Icons.people_outline, i18n.addressBookTitle),
      (Icons.tune, i18n.navigationBarSettings),
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
    return InkWell(
      // Navigate on touch-down, not release: a very light (or slightly rolling)
      // tap can drift past the tap recognizer's slop before the finger lifts and
      // get dropped. onTap stays as a no-op only to keep the ripple feedback.
      onTapDown: (_) => onTap(),
      onTap: () {},
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
    );
  }
}
