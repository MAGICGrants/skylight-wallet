// Skylight's Tor and Price settings sheets carry Cancel beside Save, as Spice's
// and the other settings sheets do. Where no Cancel is asked for the form keeps
// Save alone. (The Connection sheet's buttons are wallet_ui's ConnectionFormView,
// tested there.)
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_infra/testing.dart';
import 'package:wallet_infra/wallet_infra.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/widgets/fiat_api_settings_form.dart';
import 'package:skylight_wallet/widgets/tor_settings_form.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart' show SheetActions, WalletUiLocalizations;

void main() {
  setUp(() {
    SharedPreferencesService.store = MemoryPreferenceStore();
    TorSettingsService.sharedInstance.resetForTesting();
  });

  tearDown(() {
    SharedPreferencesService.resetForTesting();
    TorSettingsService.sharedInstance.resetForTesting();
  });

  Future<void> pumpForm(WidgetTester tester, Widget form) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          WalletUiLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: form)),
      ),
    );
    await tester.pumpAndSettle();
  }

  final forms = <String, Widget Function(VoidCallback? onCancel)>{
    'Tor': (onCancel) =>
        TorSettingsForm(saveButtonLabel: 'Save', onSaved: () {}, onCancel: onCancel),
    'Price': (onCancel) =>
        FiatApiSettingsForm(saveButtonLabel: 'Save', onSaved: () async {}, onCancel: onCancel),
  };

  for (final MapEntry(key: name, value: build) in forms.entries) {
    testWidgets('$name: a settings sheet gets Cancel beside Save', (tester) async {
      var cancelled = 0;
      await pumpForm(tester, build(() => cancelled++));
      expect(find.byType(SheetActions), findsOneWidget);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      expect(cancelled, 1);
    });

    testWidgets('$name: without onCancel, Save stands alone', (tester) async {
      await pumpForm(tester, build(null));
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });
  }
}
