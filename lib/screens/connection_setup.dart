import 'package:flutter/material.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/widgets/connection_settings_form.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

class ConnectionSetupScreen extends StatelessWidget {
  const ConnectionSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    void onSaved() {
      Navigator.pushNamed(context, '/fiat_api_setup');
    }

    return Scaffold(
      backgroundColor: BrandColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BrandSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: BrandSpacing.sm),
                  BrandScreenHeader(
                    onBack: () => Navigator.of(context).pop(),
                    center: const StepDots(count: 5, index: 1),
                  ),
                  const SizedBox(height: BrandSpacing.lg),
                  Text(i18n.lwsSetupTitle, style: BrandText.title),
                  const SizedBox(height: BrandSpacing.sm),
                  Text(i18n.lwsSetupDescription, style: BrandText.bodyMuted),
                  const SizedBox(height: BrandSpacing.xl),
                  Expanded(
                    child: SingleChildScrollView(
                      child: ConnectionSettingsForm(
                        saveButtonLabel: i18n.lwsSetupContinueButton,
                        onSaved: onSaved,
                      ),
                    ),
                  ),
                  const SizedBox(height: BrandSpacing.sm),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
