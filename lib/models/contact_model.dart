import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
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
