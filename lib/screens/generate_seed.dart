import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/screens/create_wallet.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/util/restore_qr.dart';
import 'package:spice_wallet/util/secure_screen.dart';
import 'package:spice_wallet/wallets/wallet_manager.dart';
import 'package:spice_wallet/widgets/loading_button.dart';

/// When [exportMnemonic] is set the screen shows an existing seed for backup
/// (with a QR export) instead of generating a new one.
class GenerateSeedScreenArgs {
  final String? exportMnemonic;
  final DateTime? exportRestoreDate;
  final int? exportRestoreHeight;

  const GenerateSeedScreenArgs({
    this.exportMnemonic,
    this.exportRestoreDate,
    this.exportRestoreHeight,
  });
}

class GenerateSeedScreen extends StatefulWidget {
  const GenerateSeedScreen({super.key});

  @override
  State<GenerateSeedScreen> createState() => _GenerateSeedScreenState();
}

class _GenerateSeedScreenState extends State<GenerateSeedScreen> with SecureScreenMixin {
  List<String> _seed = [];
  DateTime? _restoreDate;
  int? _restoreHeight;
  String? _mnemonic;
  bool _isCreating = false;
  bool _isExport = false;
  bool _argsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;

    final args = ModalRoute.of(context)?.settings.arguments as GenerateSeedScreenArgs?;

    if (args?.exportMnemonic != null) {
      _isExport = true;
      _mnemonic = args!.exportMnemonic;
      _seed = args.exportMnemonic!.split(' ');
      _restoreDate = args.exportRestoreDate;
      _restoreHeight = args.exportRestoreHeight;
    } else {
      final result = Provider.of<WalletManager>(context, listen: false).generateSeed();
      _mnemonic = result.mnemonic;
      _seed = result.mnemonic.split(' ');
      _restoreDate = result.restoreDate;
    }
  }

  Future<void> _continue() async {
    if (_isCreating || _mnemonic == null || _restoreDate == null) return;

    setState(() {
      _isCreating = true;
    });

    final manager = Provider.of<WalletManager>(context, listen: false);

    try {
      await manager.restoreAll(bip39Mnemonic: _mnemonic!, restoreDate: _restoreDate!);
    } catch (error) {
      log(LogLevel.error, error.toString());
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
        Navigator.pushNamed(
          context,
          '/create_wallet',
          arguments: CreateWalletScreenArgs(toastMessage: 'Sorry, something went wrong.'),
        );
      }
      return;
    }

    manager.syncInBackground();

    if (mounted) {
      Provider.of<FiatRateModel>(context, listen: false).startService(walletManager: manager);
      Navigator.pushNamedAndRemoveUntil(context, '/wallet_home', (Route<dynamic> route) => false);
    }
  }

  void _showQrCode() {
    final i18n = AppLocalizations.of(context)!;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final qrData = buildRestoreQr(seed: _mnemonic!, height: _restoreHeight);
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth.clamp(0.0, 420.0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        constraints: BoxConstraints.tightFor(width: dialogWidth),
        insetPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        title: Text(i18n.exportSeedQrTitle),
        content: QrImageView(
          data: qrData,
          eyeStyle: QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: isDarkTheme ? Colors.grey[300] : Colors.black,
          ),
          dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: isDarkTheme ? Colors.grey[300] : Colors.black,
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n.close))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: _isExport ? AppBar(title: Text(i18n.exportSeedTitle)) : null,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: EdgeInsetsGeometry.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 20,
                children: [
                  Text(
                    _isExport ? i18n.exportSeedTitle : i18n.generateSeedTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _isExport ? i18n.exportSeedWarning : i18n.generateSeedDescription,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 4,
                    children: _seed.map((word) => Chip(label: Text(word))).toList(),
                  ),
                  if (_restoreDate != null)
                    Text(
                      '${i18n.restoreWalletRestoreDateLabel}: ${MaterialLocalizations.of(context).formatCompactDate(_restoreDate!)}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  if (_isExport && _restoreHeight != null)
                    Text(
                      '${i18n.exportSeedRestoreHeightLabel}: $_restoreHeight',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  if (_isExport)
                    FilledButton.icon(
                      onPressed: _showQrCode,
                      icon: Icon(Icons.qr_code),
                      label: Text(i18n.exportSeedQrButton),
                    )
                  else
                    LoadingButton(
                      isLoading: _isCreating,
                      onPressed: _continue,
                      label: i18n.generateSeedContinueButton,
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
