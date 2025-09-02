import 'dart:convert';
import 'dart:io';

Future<int> getCurrentBlockchainHeight() async {
  final urls = [
    'https://xmr-node.cakewallet.com:18081/get_height',
    'https://node.sethforprivacy.com:18089/get_height',
    'https://node3.monerodevs.org:18089/get_height',
  ];

  for (String url in urls) {
    try {
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close().timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(
          await response.transform(utf8.decoder).join(),
        );

        if (jsonData['height'] is int) {
          return jsonData['height'];
        }
      }
    } catch (e) {
      //
    }
  }

  throw Exception('Failed to load height from all provided URLs');
}
