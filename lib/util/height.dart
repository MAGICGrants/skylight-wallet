import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:monero_light_wallet/util/socks_http.dart';

import 'package:monero_light_wallet/services/tor_service.dart';

Future<int> getCurrentBlockchainHeight() async {
  final urls = [
    'http://rucknium757bokwv3ss35ftgc3gzb7hgbvvglbg3hisp7tsj2fkd2nyd.onion:18081/get_height', // Rucknium
    'http://un4yrhwq4d53caoiaadeiur5e5wgkgp74zw3p3twqh3nxh6ztz347dad.onion:18081/get_height', // Triplebit
    'http://fz2lbxvjob6ifeonngaep2xvf2ypxjjn23i3ncblcxjreovev56ubyyd.onion:18089/get_height', // Unredacted
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
