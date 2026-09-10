import 'package:flutter/material.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/util/secure_clipboard.dart';
import 'package:skylight_wallet/util/secure_screen.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

class SecretKeysScreen extends StatefulWidget {
  const SecretKeysScreen({super.key});

  @override
  State<SecretKeysScreen> createState() => _SecretKeysScreenState();
}

class _SecretKeysScreenState extends State<SecretKeysScreen> with SecureScreenMixin {
  ({
    String? bip39,
    String legacy,
    String polyseed,
    String publicSpendKey,
    String secretSpendKey,
    String publicViewKey,
  })?
  _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wallet = appWalletOf(context);
    // Sequential to avoid concurrent native reads on the same wallet.
    final stored = await wallet.readStoredSeed();
    final legacy = await wallet.readLegacySeed();
    final polyseed = await wallet.readPolyseed();
    final publicSpendKey = await wallet.readPublicSpendKey();
    final secretSpendKey = await wallet.readSecretSpendKey();
    final publicViewKey = await wallet.readPublicViewKey();
    if (!mounted) return;
    setState(() {
      _data = (
        // The derived legacy seed can't reconstruct a bip39, so show the
        // original words when they were persisted (see SeedStore).
        bip39: stored?.format == 'bip39' ? stored!.mnemonic : null,
        legacy: legacy,
        polyseed: polyseed,
        publicSpendKey: publicSpendKey,
        secretSpendKey: secretSpendKey,
        publicViewKey: publicViewKey,
      );
    });
  }

  void _copy(String value, {required bool sensitive}) {
    if (value.isEmpty) return;
    SecureClipboard.copy(value);
    final i18n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.copiedToClipboard)));
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final data = _data;

    if (data == null) {
      return Scaffold(
        backgroundColor: BrandColors.paper,
        body: const SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    // Seeds and the secret spend key are blurred until revealed; the public keys
    // aren't sensitive.
    return KeyRevealView(
      title: i18n.secretKeysTitle,
      description: i18n.secretKeysDescription,
      warning: i18n.secretKeysWarning,
      revealLabel: i18n.generateSeedReveal,
      onCopy: _copy,
      onBack: () => Navigator.pop(context),
      fields: [
        if (data.bip39 != null)
          KeyRevealField(
            label: '${i18n.secretKeysMnemonic} (bip39)',
            value: data.bip39!,
            revealable: true,
          ),
        KeyRevealField(
          label: '${i18n.secretKeysMnemonic} (legacy)',
          value: data.legacy,
          revealable: true,
        ),
        if (data.polyseed.isNotEmpty)
          KeyRevealField(
            label: '${i18n.secretKeysMnemonic} (polyseed)',
            value: data.polyseed,
            revealable: true,
          ),
        KeyRevealField(
          label: i18n.secretKeysSecretSpendKey,
          value: data.secretSpendKey,
          revealable: true,
        ),
        KeyRevealField(
          label: i18n.secretKeysPublicSpendKey,
          value: data.publicSpendKey,
          sensitive: false,
        ),
        KeyRevealField(
          label: i18n.secretKeysPublicViewKey,
          value: data.publicViewKey,
          sensitive: false,
        ),
      ],
    );
  }
}
