// A StatefulWidget to manage the state of the notifications toggle.
import 'package:flutter/material.dart';
import 'package:monero_light_wallet/periodic_tasks.dart';
import 'package:monero_light_wallet/services/shared_preferences_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

// The state class for the SettingsScreen.
class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void _loadPreferences() async {
    final notificationsEnabled =
        await SharedPreferencesService.get<bool>(
          SharedPreferencesKeys.notificationsEnabled,
        ) ??
        false;

    setState(() {
      _notificationsEnabled = notificationsEnabled;
    });
  }

  void _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });

    if (value) {
      startNewTransactionsCheckTask();
    } else {
      cancelNewTransactionsCheckTask();
    }

    await SharedPreferencesService.set<bool>(
      SharedPreferencesKeys.notificationsEnabled,
      value,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Notify Incoming Transactions',
              style: TextStyle(fontSize: 18),
            ),
            Switch(
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
            ),
          ],
        ),
      ),
    );
  }
}
