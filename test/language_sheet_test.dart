import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/language_model.dart';
import 'package:skylight_wallet/widgets/language_sheet.dart';

/// Picking a language re-localizes the app while the picker is still the thing
/// on screen. The sheet used to be handed strings snapshotted before it opened,
/// so it stayed in the old language and the change looked like it had not taken
/// -- the screen behind it had already updated, but the sheet was covering it.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageModel>();
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale.fromSubtags(languageCode: language.language),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('behind:${AppLocalizations.of(context)!.settingsLanguageLabel}'),
                ElevatedButton(
                  onPressed: () => showLanguageSheet(context),
                  child: const Text('open'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('the picker re-localizes itself when a language is chosen', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageModel>(create: (_) => LanguageModel(), child: const _Root()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // English chrome: title, subtitle and the Done button.
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Pick your language and localization.'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Português'));
    await tester.pumpAndSettle();

    // The sheet is still open, and now speaks Portuguese.
    expect(find.text('Idioma'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
    expect(find.text('Done'), findsNothing);

    // The locale names stay as they are -- each listed in its own language.
    expect(find.text('English'), findsWidgets);
    expect(find.text('Português'), findsOneWidget);

    // And the screen underneath followed too.
    expect(find.text('behind:Idioma'), findsOneWidget);
  });
}
