import 'package:flutter/material.dart';

class TermsOfService extends StatelessWidget {
  const TermsOfService({super.key});

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
      appBar: AppBar(title: Text('Terms of Service')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Updated 2025-09-19', style: bodyStyle),
              SizedBox(height: 12),

              sectionHeading('Acceptance'),
              paragraph(
                'These Terms of Service (ToS) are entered into by and between You and MAGIC Grants, a Colorado nonprofit corporation (“we” or “us”). These terms govern your access to and use of Skylight Wallet (the “App”).',
              ),
              paragraph(
                'Please read the Terms of Service carefully before you start to use the App. By using the App you accept and agree to be bound and abide by these Terms of Service and our Privacy Policy. If you do not agree to these Terms of Service or the Privacy Policy, then you must not access or use the App.',
              ),

              sectionHeading('Updates to the Terms of Service'),
              paragraph(
                'We may revise and update these Terms of Service from time to time in our sole discretion. All changes are effective immediately when we post them, and apply to all access to and use of the App thereafter.',
              ),
              paragraph(
                'Your continued use of the App following the posting of revised Terms of Service means that you accept and agree to the changes. You are expected to check this page from time to time so you are aware of any changes, as they are binding on you.',
              ),

              sectionHeading('All MIT License Terms Apply'),
              paragraph(
                'The App is released under the MIT open source license permission notice, incorporated below:',
              ),

              Container(
                width: double.infinity,
                // padding: EdgeInsets.symmetric(vertical: 12),
                margin: EdgeInsets.only(bottom: 10.0),
                decoration: BoxDecoration(
                  // color: Theme.of(
                  //   context,
                  // ).colorScheme.surfaceVariant.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Text(
                  'THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.',
                  style: monospaceStyle,
                ),
              ),

              sectionHeading('Security'),
              paragraph(
                'You are fully responsible for the security of your funds when using the App. You agree that MAGIC Grants is not liable for your loss of funds, including due to any bugs that are present in the application. You agree that MAGIC Grants has not warranted that the App is secure for your desired purpose. You agree that MAGIC Grants has not claimed that the App is bug-free.',
              ),
              paragraph(
                'You acknowledge that MAGIC Grants is not responsible for any loss of funds or other harms that could arise from related networks and software, including but not limited to the cryptocurrency networks that you connect to.',
              ),

              sectionHeading('No Custody by MAGIC Grants'),
              paragraph(
                'MAGIC Grants, the developer of this App, does not have custody of your funds while you are using the App. Skylight Wallet is a self-custody wallet. MAGIC Grants does not transmit funds for You. MAGIC Grants is not an exchange or money services business.',
              ),
              paragraph(
                'The App does not store cryptocurrencies, including Monero, Litecoin or Bitcoin. Cryptocurrencies exist only by virtue of the ownership record maintained in their respective networks. Any transfer of title in cryptocurrency occurs within a decentralized cryptocurrency network, and not in the App.',
              ),

              sectionHeading('Restricted Use'),
              paragraph(
                'You may not use the App if it is prohibited in your jurisdiction. You may not use the App in connection with an illegal purpose. You are responsible for compliance with local laws and regulations.',
              ),

              sectionHeading('Third Party Services'),
              paragraph(
                'The App includes links to other sites and resources provided by third parties, and the App incorporates information provided by third parties for convenience. MAGIC Grants does not guarantee that these sites, resources, and information are accurate or fit for Your desired purpose. We have no control over the contents of those sites or resources, and accept no responsibility for them or for any loss or damage that may arise from your use of them. If you decide to access any of the third-party services linked in this App, you do so entirely at your own risk and subject to the terms and conditions of use for such Apps.',
              ),

              sectionHeading('Tax Matters'),
              paragraph(
                'The users of the App are solely responsible in determining what, if any, taxes apply to their cryptocurrency transactions. We are not responsible for determining any taxes that apply to such transactions.',
              ),

              sectionHeading('Indemnification'),
              paragraph(
                "You agree to defend, indemnify, and hold harmless MAGIC Grants, its affiliates, licensors, and service providers, and its and their respective officers, directors, employees, contractors, agents, licensors, suppliers, successors, and assigns from and against any claims, liabilities, damages, judgments, awards, losses, costs, expenses, or fees (including reasonable attorneys' fees) arising out of or relating to your violation of these Terms of Service or your use of the App, including, but not limited to, any use of the App's content, services, and products other than as expressly authorized in these Terms of Service, or your use of any information obtained from the App.",
              ),

              sectionHeading('Governing Law and Jurisdiction'),
              paragraph(
                'All matters relating to the App and these Terms of Service, and any dispute or claim arising therefrom or related thereto (in each case, including non-contractual disputes or claims), shall be governed by and construed in accordance with the internal laws of the State of Colorado without giving effect to any choice or conflict of law provision or rule (whether of the State of Colorado or any other jurisdiction).',
              ),
              paragraph(
                'Any legal suit, action, or proceeding arising out of, or related to, these Terms of Service or the App shall be instituted exclusively in the federal courts of the United States or the courts of the State of Colorado, although we retain the right to bring any suit, action, or proceeding against you for breach of these Terms of Service in your country of residence or any other relevant country. You waive any and all objections to the exercise of jurisdiction over you by such courts and to venue in such courts.',
              ),

              sectionHeading('Arbitration'),
              paragraph(
                'At our sole discretion, we may require You to submit any disputes arising from these Terms of Service or use of the App, including disputes arising from or concerning their interpretation, violation, invalidity, non-performance, or termination, to final and binding arbitration under the Rules of Arbitration of the American Arbitration Association applying Colorado law.',
              ),

              sectionHeading('Waiver and Severability'),
              paragraph(
                'No waiver by MAGIC Grants of any term or condition set out in these Terms of Service shall be deemed a further or continuing waiver of such term or condition or a waiver of any other term or condition, and any failure of MAGIC Grants to assert a right or provision under these Terms of Service shall not constitute a waiver of such right or provision.',
              ),
              paragraph(
                'If any provision of these Terms of Service is held by a court or other tribunal of competent jurisdiction to be invalid, illegal, or unenforceable for any reason, such provision shall be eliminated or limited to the minimum extent such that the remaining provisions of the Terms of Service will continue in full force and effect.',
              ),

              sectionHeading('Entire Agreement'),
              paragraph(
                'The Terms of Service and our Privacy Policy constitute the sole and entire agreement between You and MAGIC Grants regarding the App and supersede all prior and contemporaneous understandings, agreements, representations, and warranties, both written and oral, regarding the App.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
