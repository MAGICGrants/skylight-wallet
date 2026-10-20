import 'package:flutter_test/flutter_test.dart';
import 'package:skylight_wallet/screens/history.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// The history screen's address filter.
///
/// `recipients` is one list serving both directions (the wallet's own
/// addresses on an incoming transaction, who was paid on an outgoing one), so
/// the filter needs no direction branch. What is worth pinning is the two
/// deliberate calls: change is matched, and nothing else is.
TxDetails _tx({required List<TxRecipient> recipients, int direction = 0}) => TxDetails(
  index: 0,
  direction: direction,
  hash: 'h',
  amountBaseUnits: BigInt.one,
  feeBaseUnits: BigInt.zero,
  recipients: recipients,
  accountIndex: 0,
  subaddrIndexList: const [],
  timestamp: 0,
  height: 1,
  confirmations: 1,
  key: '',
);

void main() {
  const alice = '8Alice';
  const bob = '4Bob';

  test('an incoming transaction received at the address matches', () {
    final tx = _tx(recipients: [TxRecipient(alice, BigInt.one)]);
    expect(txInvolvesAddress(tx, alice), isTrue);
  });

  test('an outgoing transaction that paid the address matches', () {
    final tx = _tx(recipients: [TxRecipient(bob, BigInt.one)], direction: 1);
    expect(txInvolvesAddress(tx, bob), isTrue);
  });

  test('change returned to the address matches', () {
    // Deliberate: a spend that sent change back to this address involved it.
    final tx = _tx(
      recipients: [TxRecipient(bob, BigInt.one), TxRecipient(alice, BigInt.two, isChange: true)],
      direction: 1,
    );
    expect(txInvolvesAddress(tx, alice), isTrue);
  });

  test('an unrelated transaction, or one with no recipients, does not match', () {
    expect(txInvolvesAddress(_tx(recipients: [TxRecipient(bob, BigInt.one)]), alice), isFalse);
    expect(txInvolvesAddress(_tx(recipients: const []), alice), isFalse);
  });

  test('matching is exact: no prefix, and base58 stays case-significant', () {
    expect(
      txInvolvesAddress(_tx(recipients: [TxRecipient('${alice}Extra', BigInt.one)]), alice),
      isFalse,
    );
    expect(
      txInvolvesAddress(_tx(recipients: [TxRecipient('4AbCd', BigInt.one)]), '4abcd'),
      isFalse,
    );
  });

  test('surrounding whitespace from a paste does not stop a match', () {
    expect(
      txInvolvesAddress(_tx(recipients: [TxRecipient(alice, BigInt.one)]), ' $alice\n'),
      isTrue,
    );
  });
}
