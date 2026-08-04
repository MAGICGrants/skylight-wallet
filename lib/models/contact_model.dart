import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:skylight_wallet/util/contacts_store.dart';
import 'package:skylight_wallet/util/logging.dart';

class Contact {
  final String id;
  final String name;
  final String address;

  Contact({required this.id, required this.name, required this.address});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'address': address};

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
    id: json['id'] as String,
    name: json['name'] as String,
    address: json['address'] as String,
  );

  Contact copyWith({String? id, String? name, String? address}) {
    return Contact(id: id ?? this.id, name: name ?? this.name, address: address ?? this.address);
  }
}

class ContactModel with ChangeNotifier {
  List<Contact> _contacts = [];

  /// Set when the address book could not be read. Saving is refused while it
  /// holds: an empty in-memory list written over a store we simply failed to
  /// open would destroy the address book.
  bool _unreadable = false;

  List<Contact> get contacts => List.unmodifiable(_contacts);

  /// True when the stored address book couldn't be read, so what's in memory
  /// isn't the whole picture and edits aren't being saved.
  bool get isUnreadable => _unreadable;

  ContactModel() {
    load();
  }

  @visibleForTesting
  Future<void> load() async {
    try {
      final storedContacts = await readEncodedContacts();

      if (storedContacts == null) {
        _unreadable = true;
        log(LogLevel.error, 'Address book could not be read; not saving over it.');
        return;
      }

      _unreadable = false;
      _contacts = storedContacts
          .map((jsonString) => Contact.fromJson(json.decode(jsonString) as Map<String, dynamic>))
          .toList();

      notifyListeners();
    } catch (e) {
      _unreadable = true;
      log(LogLevel.error, 'Error loading contacts: $e');
    }
  }

  Future<void> _saveContacts() async {
    if (_unreadable) {
      log(LogLevel.error, 'Refusing to save contacts over an address book that failed to load.');
      return;
    }

    try {
      await writeEncodedContacts(
        _contacts.map((contact) => json.encode(contact.toJson())).toList(),
      );
    } catch (e) {
      log(LogLevel.error, 'Error saving contacts: $e');
    }
  }

  Future<void> addContact(String name, String address) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final contact = Contact(id: id, name: name.trim(), address: address.trim());

    _contacts.add(contact);
    await _saveContacts();
    notifyListeners();
  }

  Future<void> updateContact(String id, String name, String address) async {
    final index = _contacts.indexWhere((contact) => contact.id == id);
    if (index != -1) {
      _contacts[index] = _contacts[index].copyWith(name: name.trim(), address: address.trim());
      await _saveContacts();
      notifyListeners();
    }
  }

  Future<void> deleteContact(String id) async {
    _contacts.removeWhere((contact) => contact.id == id);
    await _saveContacts();
    notifyListeners();
  }

  Contact? getContactById(String id) {
    try {
      return _contacts.firstWhere((contact) => contact.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Contact> searchContacts(String query) {
    if (query.isEmpty) return _contacts;

    final lowercaseQuery = query.toLowerCase();
    return _contacts.where((contact) {
      return contact.name.toLowerCase().contains(lowercaseQuery) ||
          contact.address.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }
}
