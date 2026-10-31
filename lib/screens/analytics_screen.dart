import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../app/app_theme.dart';
import '../providers/transaction_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/transaction_model.dart';

enum _AnalyticsPeriod {
  thisMonth,
  lastThreeMonths,
  thisYear,
  allTime,
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _AnalyticsPeriod _selectedPeriod = _AnalyticsPeriod.thisMonth;

  DateTime get _now => DateTime.now();

  String get _periodLabel {
    switch (_selectedPeriod) {
      case _AnalyticsPeriod.thisMonth:
        return 'This month';
      case _AnalyticsPeriod.lastThreeMonths:
        return 'Last 3 months';
      case _AnalyticsPeriod.thisYear:
        return 'This year';
      case _AnalyticsPeriod.allTime:
        return 'All time';
    }
  }

  DateTime get _startDate {
    switch (_selectedPeriod) {
      case _AnalyticsPeriod.thisMonth:
        return DateTime(_now.year, _now.month);
      case _AnalyticsPeriod.lastThreeMonths:
        return DateTime(_now.year, _now.month - 2);
      case _AnalyticsPeriod.thisYear:
        return DateTime(_now.year);
      case _AnalyticsPeriod.allTime:
        return DateTime(2000);
    }
  }

  bool _isInSelectedPeriod(TransactionModel transaction) {
    return !transaction.date.isBefore(_startDate) &&
        !transaction.date.isAfter(_now);
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = context.watch<TransactionProvider>();
    final settings = context.watch<AppSettingsProvider>();

    final periodTransactions = transactionProvider.transactions
        .where(_isInSelectedPeriod)
        .toList();

    final incomeTransactions =
        periodTransactions.where((transaction) => transaction.isIncome);
    final expenseTransactions =
        periodTransactions.where((transaction) => !transaction.isIncome);

    final totalIncome = incomeTransactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.amount,
    );

    final totalExpenses = expenseTransactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.amount,
    );

    final netSavings = totalIncome - totalExpenses;
    final savingsRate =
        totalIncome == 0 ? 0.0 : (netSavings / totalIncome) * 100;

    final categoryExpenses = <String, double>{};
    for (final transaction in expenseTransactions) {
      categoryExpenses.update(
        transaction.category,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    final categoryEntries = categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final averageDailyExpense = totalExpenses /
        (_selectedPeriod == _AnalyticsPeriod.thisMonth
            ? _now.day
            : _selectedPeriod == _AnalyticsPeriod.thisYear
                ? _now.difference(DateTime(_now.year)).inDays + 1
                : _selectedPeriod == _AnalyticsPeriod.lastThreeMonths
                    ? _now.difference(_startDate).inDays + 1
                    : (_now.difference(_startDate).inDays + 1).clamp(1, 1000000));

    final highestCategory =
        categoryEntries.isEmpty ? null : categoryEntries.first;

    final monthlyTrend = _buildMonthlyTrend(transactionProvider.transactions);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Analytics & Financial Insights',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Understand your financial habits and spending patterns.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 22),
              _buildPeriodSelector(),
              const SizedBox(height: 22),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 650;
                  final cards = [
                    _summaryCard(
                      title: 'Total Income',
                      amount: settings.formatAmount(totalIncome),
                      color: AppTheme.income,
                      icon: Icons.trending_up,
                    ),
                    _summaryCard(
                      title: 'Total Expenses',
                      amount: settings.formatAmount(totalExpenses),
                      color: AppTheme.expense,
                      icon: Icons.trending_down,
                    ),
                    _summaryCard(
                      title: 'Net Savings',
                      amount: settings.formatAmount(netSavings),
                      color: AppTheme.primary,
                      icon: Icons.savings_outlined,
                    ),
                    _summaryCard(
                      title: 'Savings Rate',
                      amount: '${savingsRate.toStringAsFixed(1)}%',
                      color: savingsRate >= 0
                          ? AppTheme.income
                          : AppTheme.expense,
                      icon: Icons.percent,
                    ),
                  ];

                  if (isWide) {
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: cards
                          .map(
                            (card) => SizedBox(
                              width: (constraints.maxWidth - 42) / 4,
                              child: card,
                            ),
                          )
                          .toList(),
                    );
                  }

                  return Column(
                    children: cards
                        .map(
                          (card) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SizedBox(width: double.infinity, child: card),
                          ),
                        )
                        .toList(),
                  );
                },
              ),

              const SizedBox(height: 24),

              _section(
                title: 'Income vs Expenses — $_periodLabel',
                child: SizedBox(
                  height: 260,
                  child: (totalIncome == 0 && totalExpenses == 0)
                      ? _emptyState('No financial activity for this period.')
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: _safeMaxY(totalIncome, totalExpenses),
                            minY: 0,
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(
                              show: true,
                              drawVerticalLine: false,
                            ),
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final label =
                                      group.x == 0 ? 'Income' : 'Expenses';
                                  return BarTooltipItem(
                                    '$label\n${settings.formatAmount(rod.toY)}',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 62,
                                  interval: _axisInterval(
                                    _safeMaxY(totalIncome, totalExpenses),
                                  ),
                                  getTitlesWidget: (value, meta) =>
                                      _buildAxisLabel(value, meta),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final label = value.toInt() == 0
                                        ? 'Income'
                                        : value.toInt() == 1
                                            ? 'Expenses'
                                            : '';
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        label,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            barGroups: [
                              _bar(0, totalIncome, AppTheme.income),
                              _bar(1, totalExpenses, AppTheme.expense),
                            ],
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              _section(
                title: 'Monthly Spending Trend',
                child: SizedBox(
                  height: 270,
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildMonthlyTrendChart(monthlyTrend, settings),
                      ),
                      const SizedBox(height: 12),
                      _buildChartLegend(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              _section(
                title: 'Category-wise Spending — $_periodLabel',
                child: categoryEntries.isEmpty
                    ? _emptyState('No expenses recorded for this period.')
                    : Column(
                        children: [
                          SizedBox(
                            height: 230,
                            child: PieChart(
                              PieChartData(
                                centerSpaceRadius: 48,
                                sectionsSpace: 3,
                                sections: List.generate(
                                  categoryEntries.length,
                                  (index) {
                                    final entry = categoryEntries[index];
                                    final color = _chartColors[
                                        index % _chartColors.length];
                                    final percentage =
                                        totalExpenses == 0
                                            ? 0.0
                                            : entry.value / totalExpenses * 100;

                                    return PieChartSectionData(
                                      value: entry.value,
                                      color: color,
                                      radius: 68,
                                      title:
                                          '${percentage.toStringAsFixed(0)}%',
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          ...List.generate(categoryEntries.length, (index) {
                            final entry = categoryEntries[index];
                            final color =
                                _chartColors[index % _chartColors.length];
                            final percentage = totalExpenses == 0
                                ? 0.0
                                : entry.value / totalExpenses * 100;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 6,
                                    backgroundColor: color,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(entry.key)),
                                  Text(
                                    '${percentage.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    settings.formatAmount(entry.value),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
              ),

              const SizedBox(height: 24),

              _section(
                title: 'Financial Insights',
                child: Column(
                  children: [
                    _insightRow(
                      icon: Icons.category_outlined,
                      title: 'Highest spending category',
                      value: highestCategory == null
                          ? 'No expenses yet'
                          : '${highestCategory.key} · ${settings.formatAmount(highestCategory.value)}',
                      color: AppTheme.expense,
                    ),
                    const Divider(height: 24),
                    _insightRow(
                      icon: Icons.calendar_today_outlined,
                      title: 'Average daily expenses',
                      value: settings.formatAmount(averageDailyExpense),
                      color: AppTheme.primary,
                    ),
                    const Divider(height: 24),
                    _insightRow(
                      icon: Icons.receipt_long_outlined,
                      title: 'Transactions in this period',
                      value: periodTransactions.length.toString(),
                      color: AppTheme.income,
                    ),
                    const Divider(height: 24),
                    _insightRow(
                      icon: savingsRate >= 0
                          ? Icons.thumb_up_alt_outlined
                          : Icons.warning_amber_outlined,
                      title: 'Savings observation',
                      value: totalIncome == 0
                          ? 'Add income to calculate your savings rate.'
                          : savingsRate >= 20
                              ? 'Good savings progress.'
                              : savingsRate >= 0
                                  ? 'Consider increasing your savings.'
                                  : 'Expenses are higher than income.',
                      color: savingsRate >= 0
                          ? AppTheme.income
                          : AppTheme.expense,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              _section(
                title: 'Financial Summary',
                child: Column(
                  children: [
                    _summaryRow(
                      'Total Income',
                      settings.formatAmount(totalIncome),
                      AppTheme.income,
                    ),
                    const Divider(),
                    _summaryRow(
                      'Total Expenses',
                      settings.formatAmount(totalExpenses),
                      AppTheme.expense,
                    ),
                    const Divider(),
                    _summaryRow(
                      'Net Savings',
                      settings.formatAmount(netSavings),
                      netSavings >= 0 ? AppTheme.primary : AppTheme.expense,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const List<Color> _chartColors = [
    AppTheme.primary,
    AppTheme.income,
    AppTheme.expense,
    Colors.orange,
    Colors.blue,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  Widget _buildPeriodSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _periodChip('This month', _AnalyticsPeriod.thisMonth),
        _periodChip('Last 3 months', _AnalyticsPeriod.lastThreeMonths),
        _periodChip('This year', _AnalyticsPeriod.thisYear),
        _periodChip('All time', _AnalyticsPeriod.allTime),
      ],
    );
  }

  Widget _periodChip(String label, _AnalyticsPeriod period) {
    final selected = _selectedPeriod == period;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _selectedPeriod = period;
        });
      },
      selectedColor: const Color(0xFFEDE7FC),
      labelStyle: TextStyle(
        color: selected ? AppTheme.primaryDark : AppTheme.textSecondary,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected ? AppTheme.primary : Colors.transparent,
      ),
    );
  }

  List<_MonthlyTotal> _buildMonthlyTrend(
    List<TransactionModel> transactions,
  ) {
    final months = <DateTime>[];
    for (var i = 5; i >= 0; i--) {
      months.add(DateTime(_now.year, _now.month - i));
    }

    return months.map((month) {
      double income = 0;
      double expenses = 0;

      for (final transaction in transactions) {
        if (transaction.date.year == month.year &&
            transaction.date.month == month.month) {
          if (transaction.isIncome) {
            income += transaction.amount;
          } else {
            expenses += transaction.amount;
          }
        }
      }

      return _MonthlyTotal(
        month: month,
        income: income,
        expenses: expenses,
      );
    }).toList();
  }

  Widget _buildMonthlyTrendChart(
    List<_MonthlyTotal> monthlyTrend,
    AppSettingsProvider settings,
  ) {
    final maxValue = monthlyTrend.fold<double>(
      0,
      (current, item) => [
        current,
        item.income,
        item.expenses,
      ].reduce((a, b) => a > b ? a : b),
    );

    if (maxValue == 0) {
      return _emptyState('No monthly activity available yet.');
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.25,
        minY: 0,
        groupsSpace: 18,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(
          show: true,
          drawVerticalLine: false,
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = monthlyTrend[group.x];
              final label = rodIndex == 0 ? 'Income' : 'Expenses';
              return BarTooltipItem(
                '${_monthName(item.month)} $label\n${settings.formatAmount(rod.toY)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 62,
              interval: _axisInterval(maxValue * 1.25),
              getTitlesWidget: (value, meta) => _buildAxisLabel(value, meta),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= monthlyTrend.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _monthName(monthlyTrend[index].month),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(monthlyTrend.length, (index) {
          final item = monthlyTrend[index];
          return BarChartGroupData(
            x: index,
            barsSpace: 5,
            barRods: [
              BarChartRodData(
                toY: item.income,
                color: AppTheme.income,
                width: 10,
                borderRadius: BorderRadius.circular(4),
              ),
              BarChartRodData(
                toY: item.expenses,
                color: AppTheme.expense,
                width: 10,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }

  String _monthName(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[date.month - 1];
  }

  double _axisInterval(double maxY) {
    if (maxY <= 0) return 1;

    final rawInterval = maxY / 5;
    final magnitude = math.pow(10, (math.log(rawInterval) / math.ln10).floor()).toDouble();
    final normalized = rawInterval / magnitude;

    final niceStep = normalized >= 5
        ? 5
        : normalized >= 2
            ? 2
            : 1;

    return niceStep * magnitude;
  }

  Widget _buildAxisLabel(double value, TitleMeta meta) {
    final absoluteValue = value.abs();
    String label;

    if (absoluteValue >= 100000) {
      label = '₹${(value / 100000).toStringAsFixed(1)}L';
    } else if (absoluteValue >= 1000) {
      label = '₹${(value / 1000).toStringAsFixed(0)}K';
    } else {
      label = '₹${value.toStringAsFixed(0)}';
    }

    return SideTitleWidget(
      meta: meta,
      space: 8,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildChartLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      runSpacing: 8,
      children: [
        _legendItem('Income', AppTheme.income),
        _legendItem('Expenses', AppTheme.expense),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  double _safeMaxY(double first, double second) {
    final value = first > second ? first : second;
    return value <= 0 ? 1 : value * 1.25;
  }

  BarChartGroupData _bar(int x, double value, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          color: color,
          width: 42,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _insightRow({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String title, String value, Color color) {
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

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}

class _MonthlyTotal {
  final DateTime month;
  final double income;
  final double expenses;

  const _MonthlyTotal({
    required this.month,
    required this.income,
    required this.expenses,
  });
}
