import 'dart:convert';
import 'dart:io';

import 'package:skylight_wallet/util/socks_socket.dart';

class ParsedHttpResponse {
  final String httpVersion;
  final int statusCode;
  final String reasonPhrase;
  final Map<String, String> headers;
  final String body;
  final dynamic jsonBody; // Holds the decoded JSON if applicable

  ParsedHttpResponse({
    required this.httpVersion,
    required this.statusCode,
    required this.reasonPhrase,
    required this.headers,
    required this.body,
    this.jsonBody,
  });

  @override
  String toString() {
    return '''
--- PARSED RESPONSE ---
HTTP Version: $httpVersion
Status Code: $statusCode
Reason Phrase: $reasonPhrase
Headers: $headers
Body: $body
Decoded JSON: $jsonBody
-----------------------''';
  }
}

String getRawHttpRequestString(String method, String url, {Object? jsonBody}) {
  final uri = Uri.parse(url);
  final host = uri.host;

  final path = uri.path.isEmpty ? '/' : uri.path;
  final query = uri.hasQuery ? '?${uri.query}' : '';
  final fullPath = '$path$query';

  final request = StringBuffer();

  request.write('${method.toUpperCase()} $fullPath HTTP/1.1\r\n');
  request.write('Host: $host\r\n');
  request.write('Connection: close\r\n');
  request.write('Accept: */*\r\n');

  final jsonBodyStr = jsonBody is Object ? jsonEncode(jsonBody) : null;

  if (jsonBodyStr != null && jsonBodyStr.isNotEmpty) {
    final bodyBytes = utf8.encode(jsonBodyStr);
    request.write('Content-Type: application/json; charset=UTF-8\r\n');
    request.write('Content-Length: ${bodyBytes.length}\r\n');
  }

  request.write('\r\n');

  if (jsonBodyStr != null && jsonBodyStr.isNotEmpty) {
    request.write(jsonBodyStr);
  }

  return request.toString();
}

ParsedHttpResponse parseHttpResponse(String rawResponse) {
  final separator = '\r\n\r\n';
  final separatorIndex = rawResponse.indexOf(separator);

  if (separatorIndex == -1) {
    throw FormatException(
      'Invalid HTTP response: No header/body separator found.',
    );
  }

  final headersPart = rawResponse.substring(0, separatorIndex);
  final body = rawResponse.substring(separatorIndex + separator.length);
  final headerLines = headersPart.split('\r\n');

  final statusLine = headerLines.first;
  final statusLineParts = statusLine.split(' ');
  final httpVersion = statusLineParts[0];
  final statusCode = int.parse(statusLineParts[1]);
  final reasonPhrase = statusLineParts.sublist(2).join(' ');

  final headers = <String, String>{};
  for (var i = 1; i < headerLines.length; i++) {
    final line = headerLines[i];
    final colonIndex = line.indexOf(':');
    if (colonIndex != -1) {
      final key = line.substring(0, colonIndex).trim().toLowerCase();
      final value = line.substring(colonIndex + 1).trim();
      headers[key] = value;
    }
  }

  dynamic jsonBody;
  if (headers['content-type']?.contains('application/json') ?? false) {
    try {
      jsonBody = jsonDecode(body);
    } catch (e) {
      jsonBody = null;
    }
  }

  return ParsedHttpResponse(
    httpVersion: httpVersion,
    statusCode: statusCode,
    reasonPhrase: reasonPhrase,
    headers: headers,
    body: body,
    jsonBody: jsonBody,
  );
}

Future<ParsedHttpResponse> makeSocksHttpRequest(
  String method,
  String url,
  ({InternetAddress host, int port}) proxyInfo,
) async {
  final uri = Uri.parse(url);

  final socket = await SOCKSSocket.create(
    proxyHost: proxyInfo.host.address,
    proxyPort: proxyInfo.port,
    sslEnabled: uri.scheme == 'https',
  );

  await socket.connect();
  await socket.connectTo(uri.host, uri.port);

  final rawRequest = getRawHttpRequestString(method, url);
  final rawResponse = await socket.send(rawRequest);
  final parsedResponse = parseHttpResponse(rawResponse);

  return parsedResponse;
}
