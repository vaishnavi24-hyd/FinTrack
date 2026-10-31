
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsProvider extends ChangeNotifier {
  static const String _nameKey = 'fintrack_profile_name';
  static const String _emailKey = 'fintrack_profile_email';
  static const String _currencyKey = 'fintrack_currency_code';

  String _profileName = 'FinTrack User';
  String _email = 'user@example.com';

  String get profileName => _profileName;
  String get email => _email;
  String get currencyCode => 'INR';
  String get currencyName => 'Indian Rupee';
  String get currencySymbol => '₹';

  String formatAmount(num amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(amount);
  }

  Future<void> loadSettings() async {
    final preferences = await SharedPreferences.getInstance();

    _profileName =
        preferences.getString(_nameKey) ?? 'FinTrack User';

    _email =
        preferences.getString(_emailKey) ?? 'user@example.com';

    await preferences.setString(_currencyKey, 'INR');

    notifyListeners();
  }

  Future<void> updateProfile({
    required String name,
    required String email,
  }) async {
    final cleanedName = name.trim();
    final cleanedEmail = email.trim();

    if (cleanedName.isEmpty || cleanedEmail.isEmpty) {
      throw ArgumentError('Name and email cannot be empty.');
    }

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_nameKey, cleanedName);
    await preferences.setString(_emailKey, cleanedEmail);

    _profileName = cleanedName;
    _email = cleanedEmail;

    notifyListeners();
  }
}
