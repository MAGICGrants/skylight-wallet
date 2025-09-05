import 'dart:convert';
import 'package:monero_light_wallet/util/socks_http.dart';

import 'package:monero_light_wallet/services/tor_service.dart';

Future<int> getCurrentBlockchainHeight() async {
  final urls = [
    'https://xmr-node.cakewallet.com:18081/get_height',
    'https://node.sethforprivacy.com:18089/get_height',
    'https://node3.monerodevs.org:18089/get_height',
  ];

  final proxyInfo = TorService.sharedInstance.getProxyInfo();

  for (String url in urls) {
    try {
      final response = await makeSocksHttpRequest('GET', url, proxyInfo);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['height'] is int) {
          return jsonResponse['height'];
        }
      }
    } catch (e) {
      //
    }
  }

  throw Exception('Failed to load height from all provided URLs');
}
