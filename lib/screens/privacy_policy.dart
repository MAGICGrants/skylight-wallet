import 'package:flutter/material.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';

class BulletList extends StatelessWidget {
  final List<String> items;
  const BulletList({super.key, required this.items});

  Widget _buildBullet(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 6.0, right: 8.0),
            child: Icon(Icons.circle, size: 8),
          ),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map(_buildBullet).toList(),
      ),
    );
  }
}

class PrivacyPolicy extends StatelessWidget {
  const PrivacyPolicy({super.key});

  TextStyle get headingStyle => TextStyle(fontSize: 20, fontWeight: FontWeight.bold);

  TextStyle get subheadingStyle => TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  TextStyle get bodyStyle => TextStyle(fontSize: 14, height: 1.4);

  TextStyle get monospaceStyle => TextStyle(fontSize: 13, fontFamily: 'Ubuntu Mono', height: 1.4);

  Widget sectionHeading(String text) => Padding(
    padding: EdgeInsets.only(top: 18.0, bottom: 6.0),
    child: Text(text, style: subheadingStyle),
  );

  Widget paragraph(String text) => Padding(
    padding: EdgeInsets.only(bottom: 10.0),
    child: Text(text, style: bodyStyle),
  );

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    return Scaffold(
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
                    onBack: () => Navigator.pop(context),
                    center: Text(
                      i18n.welcomePrivacyLink,
                      style: BrandText.appBar.copyWith(fontSize: 16),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Updated 2026-09-03', style: bodyStyle),
                        SizedBox(height: 32),

                        paragraph(
                          'MAGIC Grants (“we”) respect your privacy and are committed to protecting it through our compliance with this policy.',
                        ),
                        paragraph(
                          'This policy applies to information we collect through your direct use of the Skylight Wallet and/or Spice Wallet app (the "App"). It does not apply to information we collect by any other means. This policy is subject to change, so make sure to periodically review this policy.',
                        ),

                        sectionHeading('Information We Do Not Collect'),
                        paragraph(
                          'We do not collect any usage data. The App does not send any private keys, including private spend keys, mnemonic seeds, and private view keys to MAGIC Grants. The App does not connect to any servers run by MAGIC Grants.',
                        ),
                        paragraph(
                          'You do not need to make an account with MAGIC Grants to use the app.',
                        ),
                        paragraph(
                          'MAGIC Grants may be able to review information provided by the App Store that you are using, if you download this app from an App Store.',
                        ),

                        sectionHeading('Information You May Share with Third Parties'),
                        paragraph(
                          'When using the App, you need to specify a server (or servers) to connect to. The information shared with a server will depend on the cryptocurrency network that you are configuring and connecting to, but it could include sensitive information including your cryptocurrency address(es), your private view key(s), and your transaction data. This is necessary for the core functionality of the App.',
                        ),
                        paragraph(
                          'You can choose to only connect to the cryptocurrency networks that you choose. It is not necessary to connect to any particular cryptocurrency network to use the App.',
                        ),
                        paragraph(
                          'MAGIC Grants does not provide default servers. You must research the servers that you want to use and any terms of service or privacy policies associated with those servers before you connect to those servers.',
                        ),
                        paragraph(
                          'In many cases, you may choose to avoid using a third party by connecting to servers that you operate. For example, instead of connecting to a node operated by a third party, you can connect to a node operated by you.',
                        ),

                        sectionHeading('Other Connections to Third Parties'),
                        paragraph(
                          'The App optionally connects to services provided by third parties for your convenience. These include:',
                        ),
                        BulletList(
                          items: [
                            'Block explorers, to display network and transaction information.',
                            'Nodes, to display network and transaction information.',
                            'Price quotes, to display richer information about your transactions.',
                          ],
                        ),
                        paragraph(
                          'Within the App, connections to these services can be configured to be routed over the Tor network, which helps improve your privacy. However, MAGIC Grants does not warrant that these connections are bug-free, or that these protections are fit for a particular purpose. Please be mindful of the third party connections that you make when using the App. The App may contain links to websites that, when clicked, open outside of Tor in your default web browser.',
                        ),
                        paragraph(
                          'Some third party connections, such as the price quotes, can be disabled in App settings.',
                        ),
                        paragraph(
                          'When you connect to third parties, you must abide by their terms of service and privacy policies.',
                        ),

                        sectionHeading('When You Contact Us'),
                        paragraph(
                          'There is no mechanism for contacting us within the App. If you contact us through a different means, then we may learn and retain information about you, such as your email address, account identifier, and the contents of your communications.',
                        ),
                        paragraph(
                          'Before sending any app diagnostic logs, make sure to review their contents for any potentially sensitive information. Remove this information before sending any information to us.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
