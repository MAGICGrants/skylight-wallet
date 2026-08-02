import 'package:flutter_test/flutter_test.dart';
import 'package:openalias_ffi/openalias_ffi.dart';

/// The OA2 test vectors from the spec, plus the OA1 records this wallet has to
/// keep resolving. Everything here is the pure record layer: no DNS, no FFI.
void main() {
  group('normalizeAlias', () {
    test('turns an email-style alias into an FQDN', () {
      expect(normalizeAlias('donate@openalias.org'), 'donate.openalias.org');
    });

    test('passes an FQDN through and drops the root dot', () {
      expect(normalizeAlias('donate.openalias.org'), 'donate.openalias.org');
      expect(normalizeAlias('donate.openalias.org.'), 'donate.openalias.org');
    });

    test('trims and lower-cases', () {
      expect(normalizeAlias('  Donate@OpenAlias.ORG '), 'donate.openalias.org');
    });

    test('rejects input with no dot as a raw address', () {
      expect(
        () => normalizeAlias('888tNkZrPN6JsEgekjMnABU4TBzc2Dt29EPAvkRxbANsAnjy'),
        throwsA(isA<NotAnAliasException>()),
      );
      expect(() => normalizeAlias('openalias'), throwsA(isA<NotAnAliasException>()));
      expect(() => normalizeAlias('   '), throwsA(isA<NotAnAliasException>()));
    });

    test('replaces the @ before deciding whether there is a dot', () {
      // Per the spec the substitution comes first, so this is a (two-label)
      // alias, not a raw address.
      expect(normalizeAlias('donate@openalias'), 'donate.openalias');
    });

    test('rejects malformed aliases', () {
      expect(() => normalizeAlias('a@b@openalias.org'), throwsA(isA<OpenAliasException>()));
      expect(() => normalizeAlias('donate..openalias.org'), throwsA(isA<OpenAliasException>()));
      expect(() => normalizeAlias('${'a' * 64}.openalias.org'), throwsA(isA<OpenAliasException>()));
    });

    test('leaves an internationalized name for the resolver to punycode', () {
      // The native resolver converts non-ASCII labels to their A-label form;
      // normalization must not mangle them first.
      expect(normalizeAlias('bob@münchen.example'), 'bob.münchen.example');
    });
  });

  group('parseKeyValueRecord', () {
    test('parses pairs, tolerating spacing and a trailing semicolon', () {
      final fields = parseKeyValueRecord('oa_version=2; network=btc;address=abc;');
      expect(fields, {'oa_version': '2', 'network': 'btc', 'address': 'abc'});
    });

    test('keeps everything after the first equals sign', () {
      final fields = parseKeyValueRecord('oa_version=2; image=https://x.example/i?a=1&b=2;');
      expect(fields!['image'], 'https://x.example/i?a=1&b=2');
    });

    test('lower-cases keys but not values', () {
      final fields = parseKeyValueRecord('OA_Version=2; Name=OpenAlias Project;');
      expect(fields, {'oa_version': '2', 'name': 'OpenAlias Project'});
    });

    test('rejects a repeated key rather than guessing', () {
      expect(parseKeyValueRecord('oa_version=2; address=a; address=b;'), isNull);
    });

    test('rejects records that are not key-value data', () {
      // An early OA2 draft used a bare `oa2 <network>` prefix; it is not valid
      // under the final spec, and must not be half-parsed into a payment.
      expect(parseKeyValueRecord('oa2 xmr address=888tNk;'), isNull);
      expect(parseKeyValueRecord('oa1:xmr recipient_address=888tNk;'), isNull);
      expect(parseKeyValueRecord('just some text'), isNull);
    });

    test('parses an unrelated TXT record that happens to be key-value shaped', () {
      // An SPF record is well-formed key-value data; what disqualifies it is the
      // missing oa_version, which the payment/metadata parsers check.
      final fields = parseKeyValueRecord('v=spf1 include:_spf.example.com ~all')!;
      expect(fields, {'v': 'spf1 include:_spf.example.com ~all'});
      expect(parseOa2Payment(fields), isNull);
    });
  });

  group('parseOa2Payment', () {
    OpenAliasPayment? parse(String text) {
      final fields = parseKeyValueRecord(text);
      return fields == null ? null : parseOa2Payment(fields);
    }

    test('parses the spec example', () {
      final record = parse(
        'oa_version=2; priority=10; network=btc; '
        'address=sp1qqfk0ag4gmq87agdy8lawrlt2mf3p8myhkuxgp5s7kdck4ywwg7mjjq; address_type=bip352;',
      )!;
      expect(record.version, 2);
      expect(record.network, 'btc');
      expect(record.asset, isNull);
      expect(record.address, 'sp1qqfk0ag4gmq87agdy8lawrlt2mf3p8myhkuxgp5s7kdck4ywwg7mjjq');
      expect(record.addressType, 'bip352');
      expect(record.priority, 10);
    });

    test('ignores unrecognized keys but keeps them', () {
      final record = parse('oa_version=2; network=btc; address=abc; future_field=somevalue;')!;
      expect(record.address, 'abc');
      expect(record.fields['future_field'], 'somevalue');
    });

    test('parses a multi-string TXT record once concatenated', () {
      // DNS may split one record into 255-byte character-strings; the native
      // resolver concatenates them in order, with no separator, before parsing.
      const first = 'oa_version=2; network=xmr; address=46BeWrHpwXmHDpDEUmZBWZfoQpdc6HaERCNmx1p';
      const second = 'EYL2rAcuwufPN9rXHHtyUA4QVy66qeFQkn6sfK8aHYjA3jk3o1Bv16em;';
      final record = parse('$first$second')!;
      expect(
        record.address,
        '46BeWrHpwXmHDpDEUmZBWZfoQpdc6HaERCNmx1pEYL2rAcuwufPN9rXHHtyUA4QV'
        'y66qeFQkn6sfK8aHYjA3jk3o1Bv16em',
      );
    });

    test('rejects a record that is not version 2', () {
      expect(parse('oa_version=3; network=xmr; address=abc;'), isNull);
      expect(parse('network=xmr; address=abc;'), isNull);
    });

    test('rejects a record missing a required field', () {
      expect(parse('oa_version=2; address=abc;'), isNull);
      expect(parse('oa_version=2; network=xmr;'), isNull);
      expect(parse('oa_version=2; network=xmr; address=;'), isNull);
    });

    test('parses amount and memo', () {
      final record = parse('oa_version=2; network=xmr; address=abc; amount=0.01; memo=12345;')!;
      expect(record.amount, '0.01');
      expect(record.memo, '12345');
    });
  });

  group('selectPayments', () {
    OpenAliasPayment record(String text) => parseOa2Payment(parseKeyValueRecord(text)!)!;

    test('prefers the lower priority number among payable records', () {
      // The spec's two-record example: BTC at priority 10, XMR at priority 20.
      final records = [
        record(
          'oa_version=2; priority=10; network=btc; '
          'address=sp1qqfk0ag4gmq87agdy8lawrlt2mf3p8myhkuxgp5s7kdck4ywwg7mjjq;',
        ),
        record('oa_version=2; priority=20; network=xmr; address=46BeWrHpwXmHDpDEUmZBWZfoQ;'),
        record('oa_version=2; priority=5; network=xmr; address=888tNkZrPN6JsEgekjMnABU4TB;'),
      ];

      final payable = selectPayments(records, network: 'xmr', asset: 'xmr', nativeAsset: 'xmr');

      // The BTC record is filtered out even though it is the highest priority
      // overall: priority applies after filtering to what the sender can pay.
      expect(payable.map((r) => r.address), [
        '888tNkZrPN6JsEgekjMnABU4TB',
        '46BeWrHpwXmHDpDEUmZBWZfoQ',
      ]);
    });

    test('sorts records with no priority last, keeping published order', () {
      final records = [
        record('oa_version=2; network=xmr; address=none1;'),
        record('oa_version=2; priority=30; network=xmr; address=p30;'),
        record('oa_version=2; network=xmr; address=none2;'),
      ];

      final payable = selectPayments(records, network: 'xmr', asset: 'xmr', nativeAsset: 'xmr');
      expect(payable.map((r) => r.address), ['p30', 'none1', 'none2']);
    });

    test('treats an omitted asset and the network native asset as the same', () {
      // On Base the native asset is eth, not base: both of these are native.
      final records = [
        record('oa_version=2; network=base; address=0xA;'),
        record('oa_version=2; network=base; asset=eth; address=0xB;'),
        record('oa_version=2; network=base; asset=usdc; address=0xC;'),
      ];

      final payable = selectPayments(records, network: 'base', asset: 'eth', nativeAsset: 'eth');
      expect(payable.map((r) => r.address), ['0xA', '0xB']);
    });

    test('matches an explicitly stated native asset for xmr', () {
      final records = [
        record('oa_version=2; network=xmr; asset=xmr; address=explicit;'),
        record('oa_version=2; network=xmr; address=omitted;'),
      ];
      expect(selectPayments(records, network: 'xmr', asset: 'xmr', nativeAsset: 'xmr').length, 2);
    });

    test('does not match a token on the network when the native asset is wanted', () {
      final records = [record('oa_version=2; network=eth; asset=usdt; address=0xUSDT;')];
      expect(selectPayments(records, network: 'eth', asset: 'eth', nativeAsset: 'eth'), isEmpty);
    });

    test('matches network and asset case-insensitively', () {
      final records = [record('oa_version=2; network=XMR; asset=XMR; address=abc;')];
      expect(
        selectPayments(records, network: 'xmr', asset: 'xmr', nativeAsset: 'xmr').single.address,
        'abc',
      );
    });

    test('does not treat an omitted asset as native when the caller cannot say', () {
      final records = [record('oa_version=2; network=eth; address=0xA;')];
      expect(selectPayments(records, network: 'eth', asset: 'eth'), isEmpty);
    });
  });

  group('parseOa1Payment', () {
    test('parses a live-style oa1:xmr record', () {
      const text =
          'oa1:xmr recipient_address=888tNkZrPN6JsEgekjMnABU4TBzc2Dt29EPAvkRxbANsAnjyPbb3iQ1YBRk1'
          'UXcdRsiKc9dhwMVgN5S9cQUiyoogDavup3H; recipient_name=Monero Development; '
          'tx_description=Donation to Monero Core Team;';

      final record = parseOa1Payment(text, 'xmr')!;
      expect(record.version, 1);
      expect(record.network, 'xmr');
      expect(record.asset, 'xmr');
      expect(
        record.address,
        '888tNkZrPN6JsEgekjMnABU4TBzc2Dt29EPAvkRxbANsAnjyPbb3iQ1YBRk1'
        'UXcdRsiKc9dhwMVgN5S9cQUiyoogDavup3H',
      );
      expect(record.recipientName, 'Monero Development');
      expect(record.description, 'Donation to Monero Core Team');
    });

    test('ignores records for other assets', () {
      const text = 'oa1:btc recipient_address=1KTexdemPdxSBcG55heUuTjDRYqbC5ZL8H;';
      expect(parseOa1Payment(text, 'xmr'), isNull);
      expect(parseOa1Payment(text, 'btc')!.address, '1KTexdemPdxSBcG55heUuTjDRYqbC5ZL8H');
    });

    test('does not match a prefix that is only a prefix', () {
      expect(parseOa1Payment('oa1:xmrx recipient_address=abc;', 'xmr'), isNull);
    });

    test('ignores unrelated TXT records', () {
      expect(parseOa1Payment('v=spf1 include:_spf.example.com ~all', 'xmr'), isNull);
      expect(parseOa1Payment('oa_version=2; network=xmr; address=abc;', 'xmr'), isNull);
    });

    test('rejects a record with no recipient address', () {
      expect(parseOa1Payment('oa1:xmr recipient_name=Nobody;', 'xmr'), isNull);
    });

    test('parses the optional amount and payment id', () {
      const text = 'oa1:xmr recipient_address=888tNk; tx_amount=1.5; tx_payment_id=deadbeef;';
      final record = parseOa1Payment(text, 'xmr')!;
      expect(record.amount, '1.5');
      expect(record.memo, 'deadbeef');
    });
  });

  group('resolveFromLookups', () {
    // Shaped after the live records on privacyguides.magicgrants.org, with
    // distinct addresses per version so it is clear which one was used.
    const oa2Xmr =
        'oa_version=2; priority=10; network=xmr; asset=xmr; address=882XLsoGHjXipTq8oKF35H2;';
    const oa2Btc = 'oa_version=2; priority=5; network=btc; address=bc1q3hrzx7h45m5jjqu5rlkl6ct;';
    const oa2Metadata = 'oa_version=2; name=MAGIC Privacy Guides Fund;';
    const oa1Xmr =
        'oa1:xmr recipient_address=888tNkZrPN6JsEgekjMnABU4TB; recipient_name=Older Record;';

    OpenAliasResult resolve(OpenAliasLookups lookups) => resolveFromLookups(
      lookups,
      alias: 'privacyguides.magicgrants.org',
      network: 'xmr',
      asset: 'xmr',
      nativeAsset: 'xmr',
    );

    test('prefers a v2 record over the v1 record on the same alias', () {
      final result = resolve(
        const OpenAliasLookups(
          paymentRecords: [oa2Xmr],
          metadataRecords: [oa2Metadata],
          oa1Records: [oa1Xmr],
        ),
      );

      expect(result.version, 2);
      expect(result.payment.address, '882XLsoGHjXipTq8oKF35H2');
      expect(result.recipientName, 'MAGIC Privacy Guides Fund');
    });

    test('falls back to v1 when the alias publishes no v2 records', () {
      final result = resolve(
        const OpenAliasLookups(
          oa1Records: [oa1Xmr],
          paymentProblem: 'lookup failed: no records found',
        ),
      );

      expect(result.version, 1);
      expect(result.payment.address, '888tNkZrPN6JsEgekjMnABU4TB');
      expect(result.recipientName, 'Older Record');
      expect(result.metadata, isNull);
    });

    test('falls back to v1 when every v2 record is unparseable', () {
      // Some zones still publish the pre-final OA2 draft syntax; it must not
      // strand an alias whose v1 record still works.
      final result = resolve(
        const OpenAliasLookups(
          paymentRecords: ['oa2 xmr address=882XLsoGHjXipTq8oKF35H2;'],
          oa1Records: [oa1Xmr],
        ),
      );

      expect(result.version, 1);
    });

    test('does not fall back to v1 when v2 records exist but none are payable', () {
      // The v2 records are the recipient's current statement of where to pay
      // them; quietly using the superseded v1 address instead would be wrong.
      expect(
        () => resolve(const OpenAliasLookups(paymentRecords: [oa2Btc], oa1Records: [oa1Xmr])),
        throwsA(isA<OpenAliasException>()),
      );
    });

    test('picks the highest-priority payable v2 record and keeps the rest', () {
      final result = resolve(
        const OpenAliasLookups(
          paymentRecords: [
            oa2Btc,
            'oa_version=2; priority=20; network=xmr; address=lowerPriority;',
            oa2Xmr,
          ],
        ),
      );

      expect(result.payment.address, '882XLsoGHjXipTq8oKF35H2'); // priority 10
      expect(result.alternatives.map((r) => r.address), ['lowerPriority']); // priority 20
    });

    test('throws and reports both lookups when nothing was published', () {
      expect(
        () => resolve(
          const OpenAliasLookups(paymentProblem: 'timed out', oa1Problem: 'no TXT records'),
        ),
        throwsA(
          isA<OpenAliasException>().having(
            (e) => e.message,
            'message',
            allOf(contains('timed out'), contains('no TXT records')),
          ),
        ),
      );
    });

    test('ignores v1 records for other assets', () {
      expect(
        () => resolve(
          const OpenAliasLookups(oa1Records: ['oa1:btc recipient_address=1KTexdemPdxSBcG55he;']),
        ),
        throwsA(isA<OpenAliasException>()),
      );
    });
  });

  group('hostile records', () {
    // Record content is whatever the zone publishes. DNSSEC proves who
    // published it, not that it is sane, so nothing here may throw.
    const nasty = [
      '',
      ';;;;',
      '=',
      '=value',
      'oa_version=2',
      'oa_version=2;;;; network=xmr;; address=abc;;;;',
      'oa_version=2; network=xmr; address=;',
      'oa_version=2; network=; address=abc;',
      'oa_version=2; network=xmr; address=abc; priority=notanumber;',
      'oa_version=2; network=xmr; address=abc; priority=99999999999999999999999;',
      'oa_version=2; network=xmr; address=abc; priority=-2147483648;',
      'oa_version=2; network=xmr; address=abc; amount=NaN; memo=;',
      'oa_version=2; network=xmr; address=abc; = ;',
      'oa1:xmr',
      'oa1:xmr ',
      'oa1:xmr recipient_address=;',
      'oa1:xmr recipient_address=a; recipient_address=b;',
      'oa1:xmr=weird',
      '\u0000\u0001\u001f',
      '🙂=🙃; oa_version=2;',
    ];

    test('parsing never throws', () {
      for (final text in nasty) {
        expect(
          () {
            final fields = parseKeyValueRecord(text);
            if (fields != null) parseOa2Payment(fields);
            parseOa1Payment(text, 'xmr');
            parseMetadata([text]);
          },
          returnsNormally,
          reason: 'input: $text',
        );
      }
    });

    test('resolution never throws anything but OpenAliasException', () {
      for (final text in nasty) {
        expect(
          () => resolveFromLookups(
            OpenAliasLookups(paymentRecords: [text], metadataRecords: [text], oa1Records: [text]),
            alias: 'example.com',
            network: 'xmr',
            asset: 'xmr',
            nativeAsset: 'xmr',
          ),
          anyOf(returnsNormally, throwsA(isA<OpenAliasException>())),
          reason: 'input: $text',
        );
      }
    });

    test('an unparseable or absurd priority sorts last instead of throwing', () {
      final records = [
        parseOa2Payment(
          parseKeyValueRecord('oa_version=2; priority=notanumber; network=xmr; address=bad;')!,
        )!,
        parseOa2Payment(
          parseKeyValueRecord('oa_version=2; priority=7; network=xmr; address=good;')!,
        )!,
      ];
      final payable = selectPayments(records, network: 'xmr', asset: 'xmr', nativeAsset: 'xmr');
      expect(payable.map((r) => r.address), ['good', 'bad']);
    });

    test('an oversized address is returned verbatim for the caller to reject', () {
      // The plugin does not know what a valid address looks like; the wallet
      // validates before anything downstream sees it.
      final huge = 'A' * 60000;
      final result = resolveFromLookups(
        OpenAliasLookups(paymentRecords: ['oa_version=2; network=xmr; address=$huge;']),
        alias: 'example.com',
        network: 'xmr',
        asset: 'xmr',
        nativeAsset: 'xmr',
      );
      expect(result.payment.address, huge);
    });

    test('a record set far larger than a DNS answer still resolves in order', () {
      final many = [
        for (var i = 0; i < 2000; i++)
          'oa_version=2; priority=${2000 - i}; network=xmr; address=addr$i;',
      ];
      final result = resolveFromLookups(
        OpenAliasLookups(paymentRecords: many),
        alias: 'example.com',
        network: 'xmr',
        asset: 'xmr',
        nativeAsset: 'xmr',
      );
      expect(result.payment.address, 'addr1999'); // priority 1
      expect(result.alternatives, hasLength(1999));
    });

    test('a publisher cannot flood the error message with record content', () {
      final flood = [
        for (var i = 0; i < 50; i++) 'oa_version=2; network=${'n' * 500}$i; address=a$i;',
      ];
      expect(
        () => resolveFromLookups(
          OpenAliasLookups(paymentRecords: flood),
          alias: 'example.com',
          network: 'xmr',
          asset: 'xmr',
          nativeAsset: 'xmr',
        ),
        throwsA(
          isA<OpenAliasException>().having(
            (e) => e.message.length,
            'message length',
            lessThan(200),
          ),
        ),
      );
    });
  });

  group('parseMetadata', () {
    test('returns the first version 2 metadata record', () {
      final metadata = parseMetadata([
        'v=spf1 -all',
        'oa_version=2; name=OpenAlias Project; image=https://openalias.org/image.png;',
      ])!;
      expect(metadata['name'], 'OpenAlias Project');
      expect(metadata['image'], 'https://openalias.org/image.png');
    });

    test('ignores draft-format and non-OpenAlias records', () {
      expect(parseMetadata(['oa2 name=MAGIC Grants; image=https://x.example/i.png']), isNull);
      expect(parseMetadata(['name=No version;']), isNull);
      expect(parseMetadata([]), isNull);
    });
  });
}
