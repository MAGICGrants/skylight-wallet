import 'package:flutter/material.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';

class WalletNavigationBar extends StatelessWidget {
  final int selectedIndex;

  const WalletNavigationBar({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Hero(
      tag: 'main-navigation-bar',
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => {
          if (index == 0 && selectedIndex != 0) {Navigator.pushNamed(context, '/wallet_home')},
          if (index == 1 && selectedIndex != 1) {Navigator.pushNamed(context, '/address_book')},
          if (index == 2 && selectedIndex != 2) {Navigator.pushNamed(context, '/settings')},
        },
        destinations: [
          NavigationDestination(icon: Icon(Icons.wallet), label: i18n.navigationBarWallet),
          NavigationDestination(icon: Icon(Icons.contacts), label: i18n.addressBookTitle),
          NavigationDestination(icon: Icon(Icons.settings), label: i18n.navigationBarSettings),
        ],
      ),
    );
  }
}
