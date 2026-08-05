import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/secure_storage.dart';

/// Storage for the address book.
///
/// Contacts are names attached to Monero addresses — the user's counterparties
/// — so they live in secure storage rather than the plaintext preferences file.
/// Earlier builds kept them in preferences; [readEncodedContacts] moves those
/// across on first read and deletes the plaintext copy.
///
/// Entries are the JSON strings the contact model already encodes, held as one
/// JSON array, because secure storage stores strings and not lists.
const _storageKey = 'contacts';

/// Reads the address book, or null if it could not be read.
///
/// Null is not the same as empty, and callers must not treat it as such: an
/// unreadable store that reads as "no contacts" would be overwritten with an
/// empty list by the next save, losing the address book for good.
Future<List<String>?> readEncodedContacts() async {
  String? stored;

  try {
    stored = await secureStorage.read(key: _storageKey);
  } catch (e) {
    log(LogLevel.error, 'Could not read contacts: $e');
    return null;
  }

  if (stored == null) return _migrateFromPreferences();

  if (stored.isEmpty) return [];

  try {
    return (json.decode(stored) as List<dynamic>).cast<String>();
  } catch (e) {
    log(LogLevel.error, 'Contacts are unreadable: $e');
    return null;
  }
}

Future<void> writeEncodedContacts(List<String> contacts) async {
  await secureStorage.write(key: _storageKey, value: json.encode(contacts));
}

Future<void> clearContacts() async {
  try {
    await secureStorage.delete(key: _storageKey);
  } catch (e) {
    log(LogLevel.error, 'Could not clear contacts: $e');
  }

  // Also drop anything a build that predates the move left behind.
  await SharedPreferencesService.remove(SharedPreferencesKeys.contacts);
}

/// Moves an address book written by an earlier build out of shared preferences.
///
/// The plaintext copy is only deleted once the secure copy is safely written —
/// if that fails the contacts are still returned and still in preferences, and
/// the next launch tries again.
Future<List<String>?> _migrateFromPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  final legacy = prefs.getStringList(SharedPreferencesKeys.contacts);

  if (legacy == null) return [];

  try {
    await writeEncodedContacts(legacy);
  } catch (e) {
    log(LogLevel.error, 'Could not move contacts to secure storage: $e');
    return legacy;
  }

  await prefs.remove(SharedPreferencesKeys.contacts);
  log(LogLevel.info, 'Moved ${legacy.length} contacts out of shared preferences');

  return legacy;
}
