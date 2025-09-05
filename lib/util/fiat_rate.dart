import 'package:monero_light_wallet/util/socks_http.dart';
import 'package:monero_light_wallet/services/tor_service.dart';

Future<double> getFiatRate(String fiatCode) async {
  final pair = 'XXMRZ$fiatCode';
  final url = 'https://api.kraken.com/0/public/Ticker?pair=$pair';

  final proxyInfo = TorService.sharedInstance.getProxyInfo();
  final response = await makeSocksHttpRequest('GET', url, proxyInfo);

  if (response.statusCode == 200) {
    final rate = response.jsonBody['result']?[pair]?['o'];

    if (rate is String) {
      return double.parse(rate);
    }
  }

  throw Exception('Could not get rate.');
}
