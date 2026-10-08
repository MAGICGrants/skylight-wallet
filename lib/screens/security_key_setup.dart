import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wallet_fhse/wallet_fhse.dart' show FhseSetup, SecurityKeyRecord;

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/security_key_flow.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

/// Arguments for `/security_key_setup`.
class SecurityKeySetupArgs {
  const SecurityKeySetupArgs({this.again = false});

  /// Setting keys up again, with only the keys to keep: how a key is removed.
  final bool again;
}

/// Sets security keys up from nothing, one key at a time, and writes them only
/// on Finish. The same flow removes a key: set up again without it, and the
/// new file (new salt) is one its old credential cannot open.
class SecurityKeySetupScreen extends StatefulWidget {
  const SecurityKeySetupScreen({super.key});

  @override
  State<SecurityKeySetupScreen> createState() => _SecurityKeySetupScreenState();
}

class _SecurityKeySetupScreenState extends State<SecurityKeySetupScreen> {
  FhseSetup? _setup;
  Object? _startError;
  bool _finishing = false;
  bool _finished = false;

  bool get _again =>
      (ModalRoute.of(context)?.settings.arguments as SecurityKeySetupArgs?)?.again ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  Future<void> _begin() async {
    try {
      final setup = await beginSecurityKeySetup(context);
      if (mounted) setState(() => _setup = setup);
    } catch (e) {
      if (mounted) setState(() => _startError = e);
    }
  }

  @override
  void dispose() {
    // Leaving without Finish writes nothing.
    if (!_finished) _setup?.cancel();
    super.dispose();
  }

  Future<void> _addKey() async {
    final setup = _setup;
    if (setup == null) return;
    final added = await showAddSecurityKeySheet(
      context,
      number: setup.keys.length + 1,
      enroll: (verification, key, name) =>
          setup.addKey(authenticator: key, verification: verification, name: name),
      rename: (record, name) async => setup.rename(record.id, name),
      registeredKeys: () async => setup.keys,
    );
    if (added && mounted) setState(() {});
  }

  Future<void> _finish() async {
    final setup = _setup;
    if (setup == null || setup.keys.isEmpty) return;
    final i18n = AppLocalizations.of(context)!;

    if (setup.keys.length == 1) {
      final anyway = await showConfirmSheet(
        context: context,
        icon: Icons.warning_amber_rounded,
        iconBg: BrandColors.warningBg,
        iconColor: BrandColors.warning,
        title: i18n.securityKeysOneKeyTitle,
        body: i18n.securityKeysOneKeyBody,
        confirmLabel: i18n.securityKeysFinishAnyway,
        cancelLabel: i18n.securityKeysAddAnother,
        confirmColor: BrandColors.warning,
      );
      if (!mounted) return;
      if (!anyway) return _addKey();
    }

    setState(() => _finishing = true);
    try {
      await finishSecurityKeySetup(context, setup);
      _finished = true;
      if (!mounted) return;
      showBrandToast(context, i18n.securityKeysTurnedOn);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _finishing = false);
      final message = securityKeyErrorMessage(i18n, e);
      if (message != null) showBrandToast(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final setup = _setup;
    final keys = setup?.keys ?? const <SecurityKeyRecord>[];

    Widget body;
    if (_startError != null) {
      body = Text(
        securityKeyErrorMessage(i18n, _startError!) ?? '',
        style: BrandText.body.copyWith(color: BrandColors.error),
      );
    } else if (setup == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BrandCard(
            padding: const EdgeInsets.all(BrandSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _again ? i18n.securityKeysSetupAgainNote : i18n.securityKeysIntroBody,
                  style: BrandText.body,
                ),
                const SizedBox(height: BrandSpacing.md),
                Text(
                  i18n.securityKeysRequirements,
                  style: BrandText.caption.copyWith(color: BrandColors.inkMuted),
                ),
                const SizedBox(height: BrandSpacing.sm),
                Text(
                  i18n.securityKeysSuggestTwo,
                  style: BrandText.caption.copyWith(color: BrandColors.inkMuted),
                ),
              ],
            ),
          ),
          if (keys.isNotEmpty) ...[
            const SizedBox(height: BrandSpacing.xl),
            SettingsGroup(
              label: i18n.securityKeysYourKeys,
              tiles: [for (final key in keys) SecurityKeyTile(record: key, justAdded: true)],
            ),
          ],
        ],
      );
    }

    return PopScope(
      canPop: !_finishing,
      child: Scaffold(
        backgroundColor: BrandColors.paper,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: BrandScreenHeader(
                      onBack: _finishing ? null : () => Navigator.pop(context),
                      center: Text(
                        _again ? i18n.securityKeysSetupAgainTitle : i18n.securityKeysSetupTitle,
                        style: BrandText.appBar.copyWith(fontSize: 16),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: body,
                    ),
                  ),
                  if (setup != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: keys.isEmpty
                          ? BrandButton(
                              label: i18n.securityKeysAddFirst,
                              icon: Icons.key_outlined,
                              onPressed: _addKey,
                            )
                          : Column(
                              children: [
                                BrandButton.outline(
                                  label: i18n.securityKeysAddAnother,
                                  onPressed: _finishing ? null : _addKey,
                                ),
                                const SizedBox(height: BrandSpacing.sm),
                                BrandButton(
                                  label: i18n.securityKeysFinish,
                                  loading: _finishing,
                                  onPressed: _finishing ? null : _finish,
                                ),
                              ],
                            ),
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

/// One enrolled key: a key glyph, its name, and when it was added.
class SecurityKeyTile extends StatelessWidget {
  const SecurityKeyTile({super.key, required this.record, this.justAdded = false});

  final SecurityKeyRecord record;

  /// In the setup list, before Finish: a check rather than a date.
  final bool justAdded;

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final details = [
      if (record.serial != null) i18n.securityKeysSerial('${record.serial}'),
      if (record.addedAt.year > 1 && !justAdded)
        i18n.securityKeysAdded(DateFormat.yMMMd(locale).format(record.addedAt)),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: [
          IconBadge(
            icon: justAdded ? Icons.check : Icons.key_outlined,
            color: justAdded ? BrandColors.success : BrandColors.primaryDeep,
          ),
          const SizedBox(width: BrandSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.name, style: BrandText.listTitle),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(details, style: BrandText.caption.copyWith(color: BrandColors.inkMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
