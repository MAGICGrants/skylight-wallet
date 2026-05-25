import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/util/logging.dart';

class Contact {
  final String id;
  final String name;
  final Map<String, String> addresses;

  Contact({required this.id, required this.name, required this.addresses});

  String? addressFor(String coinSymbol) => addresses[coinSymbol.toUpperCase()];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'addresses': addresses,
  };

  factory Contact.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('addresses')) {
      final raw = json['addresses'] as Map<dynamic, dynamic>;
      return Contact(
        id: json['id'] as String,
        name: json['name'] as String,
        addresses: raw.map((k, v) => MapEntry(k.toString().toUpperCase(), v.toString())),
      );
    }

    // Legacy single-address contacts were Monero-only.
    return Contact(
      id: json['id'] as String,
      name: json['name'] as String,
      addresses: {'XMR': json['address'] as String},
    );
  }

  Contact copyWith({String? id, String? name, Map<String, String>? addresses}) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      addresses: addresses ?? this.addresses,
    );
  }

  String addressesForClipboard() {
    return addresses.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }
}

class ContactModel with ChangeNotifier {
  List<Contact> _contacts = [];

  List<Contact> get contacts => List.unmodifiable(_contacts);

  ContactModel() {
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson = prefs.getStringList(SharedPreferencesKeys.contacts) ?? [];

      _contacts = contactsJson
          .map((jsonString) => Contact.fromJson(json.decode(jsonString) as Map<String, dynamic>))
          .toList();

      notifyListeners();
    } catch (e) {
      log(LogLevel.error, 'Error loading contacts: $e');
    }
  }

  Future<void> _saveContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson = _contacts.map((contact) => json.encode(contact.toJson())).toList();

      await prefs.setStringList(SharedPreferencesKeys.contacts, contactsJson);
    } catch (e) {
      log(LogLevel.error, 'Error saving contacts: $e');
    }
  }

  Future<void> addContact(String name, Map<String, String> addresses) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final normalized = _normalizeAddresses(addresses);
    final contact = Contact(id: id, name: name.trim(), addresses: normalized);

    _contacts.add(contact);
    await _saveContacts();
    notifyListeners();
  }

  Future<void> updateContact(String id, String name, Map<String, String> addresses) async {
    final index = _contacts.indexWhere((contact) => contact.id == id);
    if (index != -1) {
      _contacts[index] = _contacts[index].copyWith(
        name: name.trim(),
        addresses: _normalizeAddresses(addresses),
      );
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

  List<Contact> searchContacts(String query, {String? coinSymbol}) {
    var results = _contacts;

    if (coinSymbol != null) {
      final symbol = coinSymbol.toUpperCase();
      results = results.where((c) => c.addressFor(symbol) != null).toList();
    }

    if (query.isEmpty) return results;

    final lowercaseQuery = query.toLowerCase();
    return results.where((contact) {
      if (contact.name.toLowerCase().contains(lowercaseQuery)) return true;
      return contact.addresses.values.any((a) => a.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }

  Map<String, String> _normalizeAddresses(Map<String, String> addresses) {
    return {
      for (final entry in addresses.entries)
        if (entry.value.trim().isNotEmpty) entry.key.toUpperCase(): entry.value.trim(),
    };
  }
}
