
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../app/app_theme.dart';
import '../providers/transaction_provider.dart';
import '../providers/app_settings_provider.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_tile.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onAddTransaction;

  const HomeScreen({
    super.key,
    required this.onAddTransaction,
  });


  IconData categoryIcon(String category) {
    switch (category) {
      case 'Salary':
      case 'Freelance':
      case 'Business':
        return Icons.account_balance_wallet_outlined;
      case 'Food & Dining':
        return Icons.restaurant_outlined;
      case 'Shopping':
        return Icons.shopping_bag_outlined;
      case 'Transportation':
        return Icons.directions_car_outlined;
      case 'Entertainment':
        return Icons.movie_outlined;
      case 'Healthcare':
        return Icons.medical_services_outlined;
      case 'Education':
        return Icons.school_outlined;
      case 'Bills & Utilities':
        return Icons.electric_bolt_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final settings = context.watch<AppSettingsProvider>();

    final income = provider.totalIncome;
    final expenses = provider.totalExpenses;
    final balance = provider.totalBalance;
    final savings = provider.monthlySavings;

    final transactions = provider.transactions;

    final isWide = MediaQuery.of(context).size.width >= 1100;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = isWide
            ? (constraints.maxWidth - 48) / 3
            : (constraints.maxWidth - 16) / 2;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1200,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Good evening!',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Here is your financial overview.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Balance card
                  _buildBalanceCard(balance, settings),

                  const SizedBox(height: 24),

                  // Dynamic summary cards
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: SummaryCard(
                          title: 'Total Income',
                          amount: settings.formatAmount(income),
                          icon: Icons.trending_up,
                          color: AppTheme.income,
                          subtitle: 'This month',
                        ),
                      ),

                      SizedBox(
                        width: cardWidth,
                        child: SummaryCard(
                          title: 'Total Expenses',
                          amount: settings.formatAmount(expenses),
                          icon: Icons.trending_down,
                          color: AppTheme.expense,
                          subtitle: 'This month',
                        ),
                      ),

                      if (isWide)
                        SizedBox(
                          width: cardWidth,
                          child: SummaryCard(
                            title: 'Monthly Savings',
                            amount: settings.formatAmount(savings),
                            icon: Icons.savings_outlined,
                            color: AppTheme.primary,
                            subtitle:
                                '${provider.savingsPercentage.toStringAsFixed(1)}% of income',
                          ),
                        ),
                    ],
                  ),

                  if (!isWide) ...[
                    const SizedBox(height: 16),
                    SummaryCard(
                      title: 'Monthly Savings',
                      amount: settings.formatAmount(savings),
                      icon: Icons.savings_outlined,
                      color: AppTheme.primary,
                      subtitle:
                          '${provider.savingsPercentage.toStringAsFixed(1)}% of income',
                    ),
                  ],

                  const SizedBox(height: 30),

                  // Quick actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: onAddTransaction,
                        child: const Text('View all'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 14,
                    runSpacing: 12,
                    children: [
                      _quickAction(
                        title: 'Add Income',
                        icon: Icons.add_circle_outline,
                        color: AppTheme.income,
                        onTap: onAddTransaction,
                      ),
                      _quickAction(
                        title: 'Add Expense',
                        icon: Icons.remove_circle_outline,
                        color: AppTheme.expense,
                        onTap: onAddTransaction,
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Weekly chart
                  _buildWeeklyOverview(
                    provider.weeklyExpenses,
                    settings,
                  ),

                  const SizedBox(height: 30),

                  // Recent transactions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Transactions',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${transactions.length} records',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: transactions.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(30),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 45,
                                  color: AppTheme.textSecondary,
                                ),
                                SizedBox(height: 12),
                                Text('No transactions yet'),
                                SizedBox(height: 5),
                                Text(
                                  'Add your first income or expense.',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: transactions
                                .take(10)
                                .map((transaction) {
                              return Column(
                                children: [
                                  TransactionTile(
                                    title: transaction.title,
                                    category: transaction.category,
                                    date: DateFormat(
                                      'dd MMM yyyy',
                                    ).format(transaction.date),
                                    amount: settings.formatAmount(
                                      transaction.amount,
                                    ),
                                    icon: categoryIcon(
                                      transaction.category,
                                    ),
                                    isIncome: transaction.isIncome,
                                    onDelete: () {
                                      provider.deleteTransaction(
                                        transaction.id,
                                      );

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Transaction deleted',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  if (transaction !=
                                      transactions.take(10).last)
                                    const Divider(height: 1),
                                ],
                              );
                            }).toList(),
                          ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalanceCard(double balance, AppSettingsProvider settings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppTheme.primary,
            AppTheme.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            settings.formatAmount(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 22),

          Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('MMMM yyyy').format(DateTime.now()),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFF0EDF6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 9),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyOverview(
    List<double> values,
    AppSettingsProvider settings,
  ) {
    const days = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    ];

    final maxValue = values.fold<double>(
      0,
      (previous, value) =>
          value > previous ? value : previous,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Spending Overview',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Your actual expense activity this week',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 25),

          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final value = values[index];

                final barHeight = maxValue == 0
                    ? 4.0
                    : 105 * value / maxValue;

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Tooltip(
                        message: settings.formatAmount(value),
                        child: Container(
                          width: 18,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(
                              alpha: value == 0 ? 0.15 : 0.4 +
                                  (0.6 * value / maxValue),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        days[index],
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
