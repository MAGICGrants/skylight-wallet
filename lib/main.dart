import 'package:flutter/material.dart';
import 'package:monero_light_wallet/notifications_service.dart';
import 'package:provider/provider.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:monero_light_wallet/screens/connection_details.dart';
import 'package:monero_light_wallet/screens/generate_seed.dart';
import 'package:monero_light_wallet/screens/receive.dart';
import 'package:monero_light_wallet/screens/send.dart';
import 'package:monero_light_wallet/screens/tx_details.dart';
import 'package:monero_light_wallet/screens/create_wallet.dart';
import 'package:monero_light_wallet/screens/restore_wallet.dart';
import 'package:monero_light_wallet/screens/restore_warning.dart';
import 'package:monero_light_wallet/screens/wallet_home.dart';
import 'package:monero_light_wallet/screens/welcome.dart';

void main() async {
  NotificationService().init();
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => WelcomeScreen(),
        '/connection_details': (context) => ConnectionDetailsScreen(),
        '/create_wallet': (context) => CreateWalletScreen(),
        '/generate_seed': (context) => GenerateSeedScreen(),
        '/restore_warning': (context) => RestoreWarningScreen(),
        '/restore_wallet': (context) => RestoreWalletScreen(),
        '/wallet_home': (context) => WalletHomeScreen(),
        '/send': (context) => SendScreen(),
        '/receive': (context) => ReceiveScreen(),
        '/tx_details': (context) => TxDetailsScreen(),
      },
    );
  }
}
