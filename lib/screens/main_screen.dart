
import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'transaction_history_screen.dart';
import 'analytics_screen.dart';
import 'add_transaction_screen.dart';
import 'budget_screen.dart';
import 'profile_screen.dart';

import '../app/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;

  void navigateTo(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  final List<NavigationDestination> destinations = const [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: 'Transactions',
    ),
    NavigationDestination(
      icon: Icon(Icons.pie_chart_outline),
      selectedIcon: Icon(Icons.pie_chart),
      label: 'Analytics',
    ),
    NavigationDestination(
      icon: Icon(Icons.add_circle_outline),
      selectedIcon: Icon(Icons.add_circle),
      label: 'Add',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_balance_wallet_outlined),
      selectedIcon: Icon(Icons.account_balance_wallet),
      label: 'Budget',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        final List<Widget> screens = [
          HomeScreen(
            onAddTransaction: () => navigateTo(3),
          ),
          const TransactionHistoryScreen(),
          const AnalyticsScreen(),
          const AddTransactionScreen(),
          const BudgetScreen(),
          const ProfileScreen(),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'FinTrack',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
                fontSize: 23,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.notifications_none,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),

          body: Row(
            children: [
              if (isDesktop)
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: navigateTo,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.white,
                  indicatorColor: const Color(0xFFEDE7FC),
                  selectedIconTheme: const IconThemeData(
                    color: AppTheme.primary,
                  ),
                  unselectedIconTheme: const IconThemeData(
                    color: AppTheme.textSecondary,
                  ),
                  selectedLabelTextStyle: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  destinations: destinations.map((item) {
                    return NavigationRailDestination(
                      icon: item.icon,
                      selectedIcon: item.selectedIcon,
                      label: Text(item.label),
                    );
                  }).toList(),
                ),

              Expanded(
                child: IndexedStack(
                  index: selectedIndex,
                  children: screens,
                ),
              ),
            ],
          ),

          bottomNavigationBar: isDesktop
              ? null
              : NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: navigateTo,
                  destinations: destinations,
                ),
        );
      },
    );
  }
}
