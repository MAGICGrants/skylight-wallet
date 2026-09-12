import 'dart:io';

import 'package:bip39/bip39.dart' as bip39;
// ignore: implementation_imports — the BIP39 English wordlist for per-word checks.
import 'package:bip39/src/wordlists/english.dart' show WORDLIST;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:polyseed/polyseed.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/util/get_height_by_date.dart';
import 'package:skylight_wallet/util/secure_screen.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart' show parseRestoreQr;

class RestoreWalletScreen extends StatefulWidget {
  const RestoreWalletScreen({super.key});

  @override
  State<RestoreWalletScreen> createState() => _RestoreWalletScreenState();
}

class _RestoreWalletScreenState extends State<RestoreWalletScreen> with SecureScreenMixin {
  static final Set<String> _wordSet = WORDLIST.toSet();

  static final _genesis = DateTime(2014, 4, 18);

  final _restoreWalletController = RestoreWalletController();
  DateTime? _restoreDate; // null once chosen = "I'm not sure" (scan from genesis)
  int _restoreHeight = 0;
  bool _scanChosen = false;
  bool _heightManuallySet = false; // date picked / QR height
  bool _isLoading = false;
  String _seedTypeId = 'polyseed'; // the view's default (first seed type)

  bool _validWord(String w) => _wordSet.contains(w);

  Future<void> _scanQrCode() async {
    final result = await Navigator.pushNamed(context, '/scan_qr');
    if (result is! String) return;

    final parsed = parseRestoreQr(result);
    if (parsed == null) return;

    _restoreWalletController.setWords(parsed.seed.trim().split(RegExp(r'\s+')));

    if (parsed.restoreHeight != null) {
      setState(() {
        _restoreHeight = parsed.restoreHeight!;
        _heightManuallySet = true;
      });
    } else {
      // No explicit height in the QR — derive it from a polyseed if possible.
      _applyPolyseedHeight(parsed.seed.trim());
    }
  }

  /// Fills the date/height fields from a polyseed's birthday, when [mnemonic] is
  /// a valid polyseed. No-op otherwise.
  void _applyPolyseedHeight(String mnemonic) {
    if (!Polyseed.isValidSeed(mnemonic)) return;

    final polyseed = Polyseed.decode(
      mnemonic,
      PolyseedLang.getByPhrase(mnemonic),
      PolyseedCoin.POLYSEED_MONERO,
    );
    final birthdayDate = DateTime.fromMillisecondsSinceEpoch(polyseed.birthday * 1000);

    setState(() {
      _restoreDate = birthdayDate;
      _scanChosen = true;
      _restoreHeight = getHeightByDate(date: birthdayDate);
    });
  }

  Future<void> _openScanFrom() async {
    final i18n = AppLocalizations.of(context)!;
    final result = await showScanFromSheet(
      context: context,
      initial: _restoreDate,
      chosen: _scanChosen,
      labels: ScanFromSheetLabels(
        title: i18n.restoreScanTitle,
        description: i18n.restoreScanDescription,
        pickMonth: i18n.restoreScanPickMonth,
        notSure: i18n.restoreScanNotSure,
        notSureDesc: i18n.restoreScanNotSureDesc,
        done: i18n.restoreScanDone,
        locale: Localizations.localeOf(context).toString(),
      ),
    );
    if (result == null) return;

    setState(() {
      _restoreDate = result.date;
      _scanChosen = true;
      // "I'm not sure" (null) scans from genesis; a month picks that month.
      _restoreHeight = getHeightByDate(date: result.date ?? _genesis);
      _heightManuallySet = true;
    });
  }

  Future<void> _restore(String mnemonic, String seedTypeId) async {
    if (_isLoading) return;

    final i18n = AppLocalizations.of(context)!;

    // Polyseed with no user-chosen restore point: derive height from its birthday.
    if (seedTypeId == 'polyseed' && !_heightManuallySet) {
      _applyPolyseedHeight(mnemonic);
    }
    final restoreHeight = _restoreHeight;

    setState(() => _isLoading = true);

    try {
      await restoreWallet(context, mnemonic: mnemonic, restoreHeight: restoreHeight);
    } on Exception catch (error) {
      final errorMsg = error.toString().replaceFirst('Exception: ', '');
      setState(() => _isLoading = false);

      if (mounted) {
        final message = errorMsg == 'Invalid mnemonic.'
            ? i18n.restoreWalletInvalidMnemonic
            : i18n.unknownError;
        showBrandToast(context, message);
      }
      return;
    } catch (error) {
      log(LogLevel.error, error.toString());
      setState(() => _isLoading = false);
      if (mounted) {
        showBrandToast(context, i18n.unknownError);
      }
      return;
    }

    setState(() => _isLoading = false);

    if (mounted) {
      Provider.of<FiatRateModel>(context, listen: false).startService();
      // Wallet Details is LWS whitelisting info; a full node needs none of it.
      if (appWalletOf(context).isNodeMode) {
        Navigator.pushNamedAndRemoveUntil(context, '/wallet_home', (Route<dynamic> route) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/lws_details',
          (Route<dynamic> route) => false,
          arguments: restoreHeight,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final isMobile = Platform.isAndroid || Platform.isIOS;

    final String scanValue;
    final TextStyle scanStyle;
    if (!_scanChosen) {
      scanValue = i18n.restoreWalletNotSet;
      scanStyle = BrandText.body.copyWith(color: BrandColors.inkFaint);
    } else if (_restoreDate != null) {
      scanValue = DateFormat.yMMM(Localizations.localeOf(context).toString()).format(_restoreDate!);
      scanStyle = BrandText.amount;
    } else {
      scanValue = i18n.restoreScanFromStart;
      scanStyle = BrandText.body;
    }

    return RestoreWalletView(
      controller: _restoreWalletController,
      restoring: _isLoading,
      onScan: isMobile ? _scanQrCode : null,
      onSeedTypeChanged: (id) => setState(() {
        _seedTypeId = id;
        _heightManuallySet = false;
      }),
      onRestore: _restore,
      // A scan-from point must be chosen first — except for polyseed, which
      // carries its own birthday to derive the restore height from.
      canRestore: () => _scanChosen || _seedTypeId == 'polyseed',
      labels: RestoreWalletLabels(
        title: i18n.restoreWalletTitle,
        subtitle: i18n.restoreWalletDescription,
        seedLength: i18n.restoreWalletSeedLength,
        paste: i18n.restoreWalletPaste,
        restoreButton: i18n.restoreWalletRestoreButton,
        badWord: (position) => i18n.restoreWalletBadWord(position),
        didYouMean: (word) => i18n.restoreWalletDidYouMean(word),
      ),
      seedTypes: [
        SeedTypeOption(
          id: 'polyseed',
          label: i18n.restoreWalletSeedTypePolyseed,
          fixedWordCount: 16,
        ),
        SeedTypeOption(
          id: 'bip39',
          label: i18n.restoreWalletSeedTypeBip39,
          lengthOptions: const [12, 15, 18, 21, 24],
          defaultLength: 12,
          isValidWord: _validWord,
          mnemonicError: (mnemonic) =>
              bip39.validateMnemonic(mnemonic) ? null : i18n.restoreWalletChecksumError,
        ),
        SeedTypeOption(id: 'legacy', label: i18n.restoreWalletSeedTypeLegacy, fixedWordCount: 25),
      ],
      restorePointFields: ScanFromCard(
        label: i18n.restoreWalletScanFrom,
        reason: i18n.restoreWalletScanFromReason,
        value: scanValue,
        valueStyle: scanStyle,
        onTap: _openScanFrom,
      ),
    );
  }
}
