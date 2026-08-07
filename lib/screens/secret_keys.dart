import 'package:flutter/material.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/util/secure_clipboard.dart';
import 'package:skylight_wallet/util/secure_screen.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';

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

  Widget _field(String label, String value) => TextFormField(
    readOnly: true,
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
      suffixIcon: IconButton(
        onPressed: () => SecureClipboard.copy(value),
        icon: const Icon(Icons.copy),
      ),
    ),
    controller: TextEditingController(text: value),
  );

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final data = _data;

    return Scaffold(
      appBar: AppBar(title: Text(i18n.secretKeysTitle)),
      body: SafeArea(
        child: data == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  spacing: 20,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(),
                    if (data.bip39 != null)
                      _field('${i18n.secretKeysMnemonic} (bip39)', data.bip39!),
                    _field('${i18n.secretKeysMnemonic} (legacy)', data.legacy),
                    if (data.polyseed.isNotEmpty)
                      _field('${i18n.secretKeysMnemonic} (polyseed)', data.polyseed),
                    _field(i18n.secretKeysPublicSpendKey, data.publicSpendKey),
                    _field(i18n.secretKeysSecretSpendKey, data.secretSpendKey),
                    _field(i18n.secretKeysPublicViewKey, data.publicViewKey),
                  ],
                ),
              ),
      ),
    );
  }
}
