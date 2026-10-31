import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'providers/transaction_provider.dart';
import 'providers/app_settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final transactionProvider = TransactionProvider();
  final appSettingsProvider = AppSettingsProvider();

  // Load all saved data before the first screen is displayed.
  await Future.wait<void>([
    transactionProvider.loadTransactions(),
    appSettingsProvider.loadSettings(),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TransactionProvider>.value(
          value: transactionProvider,
        ),
        ChangeNotifierProvider<AppSettingsProvider>.value(
          value: appSettingsProvider,
        ),
      ],
      child: const PersonalFinanceApp(),
    ),
  );
}
