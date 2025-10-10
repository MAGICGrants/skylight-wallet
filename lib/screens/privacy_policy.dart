import 'package:flutter/material.dart';

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

  TextStyle get headingStyle =>
      TextStyle(fontSize: 20, fontWeight: FontWeight.bold);

  TextStyle get subheadingStyle =>
      TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  TextStyle get bodyStyle => TextStyle(fontSize: 14, height: 1.4);

  TextStyle get monospaceStyle =>
      TextStyle(fontSize: 13, fontFamily: 'monospace', height: 1.4);

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
    return Scaffold(
      appBar: AppBar(title: Text('Privacy Policy')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Updated 2025-09-19', style: bodyStyle),
              SizedBox(height: 32),

              paragraph(
                'MAGIC Grants (“we”) respect your privacy and are committed to protecting it through our compliance with this policy.',
              ),
              paragraph(
                'This policy applies to information we collect through your direct use of the Skylight Wallet app. It does not apply to information we collect by any other means. This policy is subject to change, so make sure to periodically review this policy.',
              ),

              sectionHeading('Information We Do Not Collect'),
              paragraph(
                'We do not collect any usage data. The app does not send any private keys, including private spend keys, mnemonic seeds, and private view keys to MAGIC Grants. The app does not connect to any servers run by MAGIC Grants.',
              ),
              paragraph(
                'You do not need to make an account with MAGIC Grants to use the app.',
              ),
              paragraph(
                'MAGIC Grants may be able to review information provided by the App Store that you are using, if you download this app from an App Store.',
              ),

              sectionHeading('Information You May Share with Third Parties'),
              paragraph(
                'When using Skylight Wallet, you need to specify a server to connect to. This will share your cryptocurrency address and private view key with this server. You will also share transactions you create with this server. This is necessary for the core functionality of the wallet.',
              ),
              paragraph(
                'MAGIC Grants does not provide a default server. You must research the server that you want to use and any terms of service or privacy policies associated with that server before you connect to that server.',
              ),
              paragraph(
                'You may choose to avoid using a third party by connecting to a server that you operate.',
              ),

              sectionHeading('Other Connections to Third Parties'),
              paragraph(
                'The app connects to services provided by third parties for your convenience. These include:',
              ),
              BulletList(
                items: [
                  'Block explorers, for viewing information about your transactions.',
                  'Price quotes, for displaying richer information about your transactions.',
                  'Cryptocurrency nodes, for the app to learn information about the cryptocurrency network’s status.',
                ],
              ),
              paragraph(
                'Within the app, connections to these services are protected automatically with Tor. However, MAGIC Grants does not warrant that these connections are bug-free, or that these protections are fit for a particular purpose.',
              ),
              paragraph(
                'Please be mindful of the third party connections that you make when using the App. The App may contain links to websites that, when clicked, open outside of Tor in your default web browser.',
              ),

              sectionHeading('When You Contact Us'),
              paragraph(
                'There is no mechanism for contacting us within the application. If you contact us through a different means, then we may learn and retain information about you, such as your email address, account identifier, and the contents of your communications.',
              ),
              paragraph(
                'Before sending any app logs, make sure to review their contents for any potentially sensitive information. Remove this information before sending any information to us.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
