import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skylight_wallet/models/contact_model.dart';
import 'package:skylight_wallet/util/contacts_store.dart';

/// The address book holds the user's counterparties, so it belongs in secure
/// storage — and moving it there must not lose anyone's contacts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String encoded(String id, String name, String address) =>
      json.encode({'id': id, 'name': name, 'address': address});

  Future<List<String>?> secureContacts() async {
    final raw = await const FlutterSecureStorage().read(key: 'contacts');
    return raw == null ? null : (json.decode(raw) as List<dynamic>).cast<String>();
  }

  Future<List<String>?> plaintextContacts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('contacts');
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('a new contact is written to secure storage, not preferences', () async {
    final model = ContactModel();
    await model.load();

    await model.addContact('Alice', '4AliceAddress');

    expect(await secureContacts(), hasLength(1));
    expect(await plaintextContacts(), isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty, reason: 'nothing about contacts in plaintext');
  });

  test('contacts written by an older build are migrated and the plaintext copy removed', () async {
    SharedPreferences.setMockInitialValues({
      'contacts': [encoded('1', 'Alice', '4Alice'), encoded('2', 'Bob', '4Bob')],
    });

    final model = ContactModel();
    await model.load();

    expect(model.contacts.map((c) => c.name), ['Alice', 'Bob']);
    expect(await secureContacts(), hasLength(2));
    expect(await plaintextContacts(), isNull, reason: 'the plaintext copy must be deleted');
  });

  test('migration runs once and the secure copy wins afterwards', () async {
    SharedPreferences.setMockInitialValues({
      'contacts': [encoded('1', 'Alice', '4Alice')],
    });

    await (ContactModel()..load()).load();

    // A stale plaintext entry reappearing must not override what is already in
    // secure storage.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('contacts', [encoded('9', 'Impostor', '4Impostor')]);

    final second = ContactModel();
    await second.load();

    expect(second.contacts.map((c) => c.name), ['Alice']);
  });

  test('an unreadable address book is not overwritten by an empty one', () async {
    FlutterSecureStorage.setMockInitialValues({'contacts': 'not json'});

    final model = ContactModel();
    await model.load();

    expect(model.isUnreadable, isTrue);
    expect(model.contacts, isEmpty);

    // A save triggered while in that state would otherwise replace the stored
    // address book with the empty in-memory one.
    await model.addContact('Alice', '4Alice');

    expect(await const FlutterSecureStorage().read(key: 'contacts'), 'not json');
  });

  test('clearContacts removes both copies', () async {
    SharedPreferences.setMockInitialValues({
      'contacts': [encoded('1', 'Alice', '4Alice')],
    });
    FlutterSecureStorage.setMockInitialValues({
      'contacts': json.encode([encoded('1', 'Alice', '4Alice')]),
    });

    await clearContacts();

    expect(await secureContacts(), isNull);
    expect(await plaintextContacts(), isNull);
  });

  test('an empty address book reads as empty, not as unreadable', () async {
    FlutterSecureStorage.setMockInitialValues({'contacts': json.encode(<String>[])});

    final model = ContactModel();
    await model.load();

    expect(model.isUnreadable, isFalse);
    expect(model.contacts, isEmpty);
  });
}
