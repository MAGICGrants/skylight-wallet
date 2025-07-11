import 'package:flutter/material.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:monero_light_wallet/screens/send_transaction.dart';
import 'package:provider/provider.dart';
import 'package:monero_light_wallet/screens/create_wallet.dart';
import 'package:monero_light_wallet/screens/restore_wallet.dart';
import 'package:monero_light_wallet/screens/restore_warning.dart';
import 'package:monero_light_wallet/screens/wallet_home.dart';
import 'package:monero_light_wallet/screens/welcome.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => WalletModel(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => WelcomeScreen(),
        '/create_wallet': (context) => CreateWalletScreen(),
        '/restore_warning': (context) => RestoreWarningScreen(),
        '/restore_wallet': (context) => RestoreWalletScreen(),
        '/wallet_home': (context) => WalletHomeScreen(),
        '/send_transaction': (context) => SendTransactionScreen(),
      },
    );
  }
}
