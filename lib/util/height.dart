import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:monero_light_wallet/util/socks_http.dart';

import 'package:monero_light_wallet/services/tor_service.dart';

Future<int> getCurrentBlockchainHeight() async {
  final urls = [
    'cakexmrl7bonq7ovjka5kuwuyd3f7qnkz6z6s6dmsy3uckwra7bvggyd.onion:18081/get_height', // Cake Wallet
    'rucknium757bokwv3ss35ftgc3gzb7hgbvvglbg3hisp7tsj2fkd2nyd.onion:18081/get_height', // Rucknium
    'a6orjo6aiotog3njppja5jwnd3rexzfjiejxnojvw74p3kma45fundid.onion:18089/get_height', // StormyCloud
    'un4yrhwq4d53caoiaadeiur5e5wgkgp74zw3p3twqh3nxh6ztz347dad.onion:18081/get_height,' // Triplebit
  ];

  urls.shuffle(Random.secure());

  final proxyInfo = TorService.sharedInstance.getProxyInfo();

  for (String url in urls) {
    try {
      final response = await makeSocksHttpRequest(
        'GET',
        url,
        proxyInfo,
      ).timeout(Duration(seconds: 30));

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

  throw Exception('failedToLoadHeight');
}
