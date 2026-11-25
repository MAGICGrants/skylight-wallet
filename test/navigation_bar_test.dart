// The bottom tabs answer every kind of input, and each opens its screen once: a
// touch (which navigates on touch-down), a screen reader, Switch Access or
// Voice Access tap (which arrives as onTap alone), and the keyboard.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart' show WalletUiLocalizations;
import 'package:skylight_wallet/widgets/wallet_navigation_bar.dart';

class _Pushes extends NavigatorObserver {
  final names = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      names.add(route.settings.name);
}

void main() {
  late _Pushes pushes;

  Future<void> pumpBar(WidgetTester tester) async {
    pushes = _Pushes();
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
        navigatorObservers: [pushes],
        initialRoute: '/wallet_home',
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(
            body: Text('${settings.name}'),
            bottomNavigationBar: settings.name == '/wallet_home'
                ? const WalletNavigationBar(selectedIndex: 0)
                : null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    pushes.names.clear();
  }

  testWidgets('a touch opens the tab once', (tester) async {
    await pumpBar(tester);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(pushes.names, ['/history']);
  });

  testWidgets('a screen-reader tap opens the tab', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBar(tester);
    tester.semantics.tap(find.semantics.byLabel('History'));
    await tester.pumpAndSettle();
    expect(pushes.names, ['/history']);
    handle.dispose();
  });

  testWidgets('the tabs say which one is current', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBar(tester);
    expect(
      tester.getSemantics(find.text('History')),
      matchesSemantics(
        label: 'History',
        isButton: true,
        hasSelectedState: true,
        isSelected: false,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    expect(
      tester.getSemantics(find.text('Wallet')),
      isSemantics(label: 'Wallet', isButton: true, isSelected: true),
    );
    handle.dispose();
  });

  testWidgets('Enter on a focused tab opens it', (tester) async {
    await pumpBar(tester);
    // Wallet, then History.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(pushes.names, ['/history']);
  });

  testWidgets('the current tab does not open itself again', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBar(tester);
    await tester.tap(find.text('Wallet'));
    tester.semantics.tap(find.semantics.byLabel('Wallet'));
    await tester.pumpAndSettle();
    expect(pushes.names, isEmpty);
    handle.dispose();
  });
}
