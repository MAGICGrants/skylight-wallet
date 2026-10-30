import 'package:flutter_test/flutter_test.dart';
import 'package:skylight_wallet/main.dart' show appRouteNames;
import 'package:skylight_wallet/route_policy.dart';
import 'package:wallet_ui/wallet_ui.dart' show RouteAccess;

/// The route policy (lib/route_policy.dart) is deny by default, so it must name
/// every route, and the public ones are pinned here: making a screen reachable
/// before the unlock should be a decision, not an accident.
void main() {
  test('every route says who may open it, and nothing else is listed', () {
    final c = routePolicy.check(appRouteNames);
    expect(c.unlisted, isEmpty, reason: 'add these to lib/route_policy.dart');
    expect(c.stale, isEmpty, reason: 'remove these from lib/route_policy.dart');
  });

  test('only onboarding, the lock screens and the legal pages are public', () {
    final public = {
      for (final e in routePolicy.access.entries)
        if (e.value == RouteAccess.public) e.key,
    };
    expect(public, {
      '/welcome',
      '/tor_settings',
      '/fiat_api_setup',
      '/connection_setup',
      '/create_wallet',
      '/create_wallet_password',
      '/generate_seed',
      '/restore_wallet',
      '/scan_qr',
      '/unlock',
      '/security_key_unlock',
      '/terms_of_service',
      '/privacy_policy',
    });
  });

  test('every wallet screen waits for the unlock', () {
    for (final name in [
      '/wallet_home',
      '/send',
      '/receive',
      '/address_book',
      '/history',
      '/settings',
      '/lws_details',
      '/lws_keys',
      '/secret_keys',
      '/advanced_security',
      '/metadata_backup',
    ]) {
      expect(routePolicy.requiresUnlock(name), isTrue, reason: name);
      expect(routePolicy.allows(name, unlocked: false), isFalse, reason: name);
    }
  });
}
