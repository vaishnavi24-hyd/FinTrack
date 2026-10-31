import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../providers/transaction_provider.dart';
import '../providers/app_settings_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController nameController;
  late final TextEditingController emailController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // main() awaits loadSettings() before runApp(), so these are saved values.
    final settings = context.read<AppSettingsProvider>();
    nameController = TextEditingController(text: settings.profileName);
    emailController = TextEditingController(text: settings.email);
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();

    if (name.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid name and email address.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await context.read<AppSettingsProvider>().updateProfile(
            name: name,
            email: email,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile details saved successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final transactions = context.watch<TransactionProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Profile',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Manage your personal information and preferences.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 28),

              _card(
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 45,
                      backgroundColor: Color(0xFFEDE7FC),
                      child: Icon(
                        Icons.person,
                        size: 48,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      settings.profileName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      settings.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _sectionTitle('Personal Information'),
              const SizedBox(height: 14),

              _card(
                child: Column(
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        child: Text(
                          _isSaving ? 'Saving...' : 'Update Profile',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _sectionTitle('Preferences'),
              const SizedBox(height: 14),

              _card(
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.currency_rupee,
                    color: AppTheme.primary,
                  ),
                  title: Text('Preferred Currency'),
                  subtitle: Text('Indian Rupee (₹)'),
                  trailing: Icon(Icons.lock_outline, size: 18),
                ),
              ),

              const SizedBox(height: 24),
              _sectionTitle('Financial Overview'),
              const SizedBox(height: 14),

              _card(
                child: Column(
                  children: [
                    _financialRow(
                      'Total Income',
                      settings.formatAmount(transactions.totalIncome),
                      AppTheme.income,
                    ),
                    const Divider(),
                    _financialRow(
                      'Total Expenses',
                      settings.formatAmount(transactions.totalExpenses),
                      AppTheme.expense,
                    ),
                    const Divider(),
                    _financialRow(
                      'Current Balance',
                      settings.formatAmount(transactions.totalBalance),
                      AppTheme.primary,
                    ),
                    const Divider(),
                    _financialRow(
                      'Transactions',
                      transactions.transactions.length.toString(),
                      AppTheme.textPrimary,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _sectionTitle('About FinTrack'),
              const SizedBox(height: 14),

              _card(
                child: const ListTile(
                  leading: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppTheme.primary,
                  ),
                  title: Text('FinTrack'),
                  subtitle: Text(
                    'Personal Finance & Budget Tracker\nVersion 1.0.0',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  Widget _financialRow(String title, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
