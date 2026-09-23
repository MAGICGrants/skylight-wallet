import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/services/tor_service.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

/// The top-level desktop destinations, mirroring the mobile navigation bar
/// (Skylight has no separate History screen).
enum DesktopNav { home, addressBook, settings }

/// Shared style for a desktop screen's large title (Settings, Contacts, …).
TextStyle get desktopTitleStyle => TextStyle(
  fontFamily: 'Ubuntu',
  fontSize: 26,
  height: 1.2,
  fontWeight: FontWeight.w700,
  color: BrandColors.ink,
);

/// The "‹ label" back link at the top of a desktop sub-screen (receive, send,
/// ToS, …) — the shared back affordance in place of a mobile app bar.
class DesktopBackLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const DesktopBackLink({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Sized to its content (left-aligned) so the hover/ripple doesn't span the
    // full parent width; a little right padding keeps the ripple off the label.
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 4, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chevron_left, size: 18, color: BrandColors.primary),
              const SizedBox(width: 2),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Ubuntu',
                  fontSize: 12.5,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  color: BrandColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two-pane desktop chrome: a fixed left sidebar (brand, nav, Tor status,
/// version) with the screen's content on the right. Shared by the desktop
/// screens so the sidebar stays put.
///
/// The sidebar is a [Hero] (like the mobile nav bar) so it flies in place across
/// route transitions instead of sliding with the page — the content animates,
/// the sidebar looks fixed. Modals stay on the root navigator, so they still
/// cover (and dim) the whole window, sidebar included.
class DesktopShell extends StatefulWidget {
  final DesktopNav active;
  final Widget child;

  const DesktopShell({super.key, required this.active, required this.child});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  // Cached across shells: each nav click mounts a fresh shell, and a per-instance
  // reload would blank the version line for a frame (a flicker) every time.
  static String _cachedVersion = '';
  String _version = _cachedVersion;

  // TorService exposes no change notification, so poll its status and rebuild
  // when it flips (e.g. connecting → connected after launch).
  Timer? _torPoll;
  TorConnectionStatus _torState = TorService.sharedInstance.status;

  @override
  void initState() {
    super.initState();
    if (_cachedVersion.isEmpty) {
      PackageInfo.fromPlatform().then((info) {
        _cachedVersion = 'v${info.version} · build ${info.buildNumber}';
        if (mounted) setState(() => _version = _cachedVersion);
      });
    }
    _torPoll = Timer.periodic(const Duration(seconds: 1), (_) {
      final status = TorService.sharedInstance.status;
      if (mounted && status != _torState) setState(() => _torState = status);
    });
  }

  @override
  void dispose() {
    _torPoll?.cancel();
    super.dispose();
  }

  void _go(String route) {
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.pushNamed(context, route);
  }

  /// Readable cap for a screen's content so it doesn't span an ultra-wide window
  /// (the child adds its own gutters, so this includes ~44px each side).
  static const contentMaxWidth = 948.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.paper,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Flies in place across transitions, so the sidebar doesn't slide with
          // the page. Kept out of the page's own transition, like the mobile nav.
          // placeholderBuilder keeps it painted in place during the flight, so
          // instant (zero-duration) tab switches don't blink an empty gap.
          Hero(
            tag: 'desktop-sidebar',
            placeholderBuilder: (context, heroSize, child) => child,
            child: _sidebar(context),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: contentMaxWidth),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebar(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    // The Hero lifts this into the overlay mid-flight, outside any Scaffold, so
    // give it a Material for text styling (transparent to keep the fill).
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 236,
        decoration: BoxDecoration(
          color: BrandColors.surfaceSunken,
          border: Border(right: BorderSide(color: BrandColors.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SvgPicture.asset('assets/logo.svg', width: 28, height: 28),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Skylight Wallet',
                    style: TextStyle(
                      fontFamily: 'Ubuntu',
                      fontSize: 16,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: BrandColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _navItem(
              DesktopNav.home,
              Icons.account_balance_wallet_outlined,
              i18n.navigationBarWallet,
              '/wallet_home',
            ),
            const SizedBox(height: 2),
            _navItem(
              DesktopNav.addressBook,
              Icons.people_outline,
              i18n.addressBookTitle,
              '/address_book',
            ),
            const Spacer(),
            _navItem(DesktopNav.settings, Icons.tune, i18n.navigationBarSettings, '/settings'),
            const SizedBox(height: 6),
            _torStatus(),
            if (_version.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 14, top: 1),
                child: Text(
                  'Skylight Wallet $_version',
                  style: TextStyle(
                    fontFamily: 'Ubuntu Mono',
                    fontSize: 10.5,
                    height: 1.5,
                    color: BrandColors.inkFaint,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(DesktopNav nav, IconData icon, String label, String route) {
    // Always clickable (cursor + ripple), even when this tab is the active one;
    // _go no-ops when you're already on that exact route.
    return _navTile(
      icon: icon,
      label: label,
      active: widget.active == nav,
      onTap: () => _go(route),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback? onTap,
  }) {
    final fg = active ? BrandColors.primaryDeep : BrandColors.inkMuted;
    return Material(
      color: active ? BrandColors.paper : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: active ? BrandColors.border : Colors.transparent),
      ),
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Ubuntu',
                  fontSize: 14,
                  height: 1,
                  fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _torStatus() {
    final (Color color, String text) = switch (_torState) {
      TorConnectionStatus.connected => (BrandColors.purple, 'Tor · connected'),
      TorConnectionStatus.connecting => (BrandColors.warning, 'Tor · connecting'),
      TorConnectionStatus.disconnected => (BrandColors.inkFaint, 'Tor · off'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Ubuntu',
              fontSize: 12,
              height: 1,
              color: BrandColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
