
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../app/app_theme.dart';
import '../models/budget_model.dart';
import '../providers/transaction_provider.dart';
import '../services/pdf_report_service.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  static const List<String> _categories = [
    'Food & Dining',
    'Shopping',
    'Transportation',
    'Bills & Utilities',
    'Entertainment',
    'Healthcare',
    'Education',
    'Other',
  ];

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(amount);
  }

  Future<void> _showBudgetDialog(
    BuildContext context, {
    BudgetModel? budget,
  }) async {
    final provider = context.read<TransactionProvider>();
    final controller = TextEditingController(
      text: budget?.monthlyLimit.toStringAsFixed(0) ?? '',
    );

    String selectedCategory = budget?.category ?? _categories.first;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                budget == null ? 'Create Budget' : 'Edit Budget',
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: budget != null
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(() {
                                  selectedCategory = value;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: controller,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Monthly limit',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final amount = double.tryParse(
                          value?.trim() ?? '',
                        );

                        if (amount == null ||
                            !amount.isFinite ||
                            amount <= 0) {
                          return 'Enter a valid amount greater than zero';
                        }

                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final limit = double.parse(controller.text.trim());

                    if (budget == null) {
                      final duplicate = provider.budgets.any(
                        (item) => item.category == selectedCategory,
                      );

                      if (duplicate) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'A budget already exists for this category.',
                            ),
                          ),
                        );
                        return;
                      }

                      await provider.addBudget(
                        BudgetModel(
                          id: DateTime.now()
                              .microsecondsSinceEpoch
                              .toString(),
                          category: selectedCategory,
                          monthlyLimit: limit,
                        ),
                      );
                    } else {
                      await provider.updateBudget(
                        budget.copyWith(monthlyLimit: limit),
                      );
                    }

                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                  },
                  child: Text(
                    budget == null ? 'Create' : 'Save Changes',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    BudgetModel budget,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Budget?'),
          content: Text(
            'Are you sure you want to delete the ${budget.category} budget?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: AppTheme.expense),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await context.read<TransactionProvider>().deleteBudget(budget.id);
    }
  }

  Color _statusColor(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.normal:
        return AppTheme.income;
      case BudgetStatus.warning:
        return Colors.orange;
      case BudgetStatus.reached:
      case BudgetStatus.exceeded:
        return AppTheme.expense;
    }
  }

  String _statusLabel(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.normal:
        return 'Within budget';
      case BudgetStatus.warning:
        return 'Near limit';
      case BudgetStatus.reached:
        return 'Budget reached';
      case BudgetStatus.exceeded:
        return 'Over budget';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final budgets = provider.budgets;
    final summaries = provider.budgetSummaries();

    final totalBudget = provider.totalAllocatedBudget;
    final totalSpent = provider.totalBudgetSpent;
    final totalRemaining = provider.totalBudgetRemaining;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Budget Management'),
        backgroundColor: AppTheme.background,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Export monthly PDF report',
            onPressed: () async {
              final provider = context.read<TransactionProvider>();

              try {
                await PdfReportService.exportMonthlyReport(provider);

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Monthly PDF report is ready to share.'),
                  ),
                );
              } catch (error) {
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not generate PDF report: $error'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Add budget',
            onPressed: () => _showBudgetDialog(context),
            icon: const Icon(Icons.add_circle_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryCard(
                  totalBudget,
                  totalSpent,
                  totalRemaining,
                  provider.overBudgetCategories.length,
                ),
                const SizedBox(height: 18),
                _monthlyOverviewCard(
                  totalBudget: totalBudget,
                  totalSpent: totalSpent,
                  totalRemaining: totalRemaining,
                  categoryCount: budgets.length,
                  alertCount: provider.warningBudgetCategories.length +
                      provider.overBudgetCategories.length,
                ),
                const SizedBox(height: 18),
                _budgetComparisonChart(provider),
                const SizedBox(height: 18),
                _categoryPerformanceSection(provider),
                const SizedBox(height: 18),
                const _MonthlyBudgetReport(),
                const SizedBox(height: 18),
                _budgetAlertsSection(provider),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your Monthly Budgets',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showBudgetDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Budget'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (budgets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(
                      child: Text('No budgets yet. Create your first budget.'),
                    ),
                  ),
                ...summaries.map((summary) {
                  final budget = summary.budget;
                  final spent = summary.spent;
                  final remaining = summary.remaining;
                  final progressColor = _statusColor(summary.status);
                  final isExceeded =
                      summary.status == BudgetStatus.exceeded;
                  final isReached =
                      summary.status == BudgetStatus.reached;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(
                        color: Color(0xFFECE9F2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  budget.category,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Edit budget',
                                onPressed: () => _showBudgetDialog(
                                  context,
                                  budget: budget,
                                ),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Delete budget',
                                onPressed: () =>
                                    _confirmDelete(context, budget),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppTheme.expense,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_formatCurrency(spent)} spent',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                'Limit: ${_formatCurrency(summary.monthlyLimit)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: summary.progressValue,
                              minHeight: 9,
                              backgroundColor: const Color(0xFFECE9F2),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(
                                progressColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isExceeded
                                      ? 'Exceeded by ${_formatCurrency(-remaining)}'
                                      : isReached
                                          ? 'No budget remaining'
                                          : '${_formatCurrency(remaining)} remaining',
                                  style: TextStyle(
                                    color: isExceeded || isReached
                                        ? AppTheme.expense
                                        : AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                _statusLabel(summary.status),
                                style: TextStyle(
                                  color: progressColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${summary.utilizationPercentage.toStringAsFixed(1)}% used',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(
    double totalBudget,
    double totalSpent,
    double totalRemaining,
    int overBudgetCount,
  ) {
    final isOverBudget = totalRemaining < 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppTheme.primary,
            AppTheme.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Monthly Budget',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            _formatCurrency(totalBudget),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _summaryItem('Total Spent', totalSpent),
              ),
              Expanded(
                child: _summaryItem(
                  isOverBudget ? 'Over Budget' : 'Remaining',
                  totalRemaining.abs(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: totalBudget <= 0
                  ? 0
                  : (totalSpent / totalBudget).clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            totalBudget <= 0
                ? 'No budget allocated'
                : '${(totalSpent / totalBudget * 100).toStringAsFixed(1)}% of total budget used',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (overBudgetCount > 0) ...[
            const SizedBox(height: 14),
            Text(
              '$overBudgetCount ${overBudgetCount == 1 ? 'category has' : 'categories have'} reached or exceeded the budget limit.',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryPerformanceSection(TransactionProvider provider) {
    final summaries = provider.budgetSummaries();

    if (summaries.isEmpty) {
      return const SizedBox.shrink();
    }

    final highestSpending = summaries.reduce(
      (a, b) => a.spent >= b.spent ? a : b,
    );

    final highestUtilization = summaries.reduce(
      (a, b) => a.utilizationPercentage >= b.utilizationPercentage ? a : b,
    );

    final withinBudget = summaries
        .where((summary) => summary.status == BudgetStatus.normal)
        .length;

    final nearLimit = summaries
        .where((summary) => summary.status == BudgetStatus.warning)
        .length;

    final reachedOrExceeded = summaries
        .where((summary) =>
            summary.status == BudgetStatus.reached ||
            summary.status == BudgetStatus.exceeded)
        .length;

    final ranked = List<BudgetSummary>.from(summaries)
      ..sort(
        (a, b) => b.utilizationPercentage.compareTo(a.utilizationPercentage),
      );

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFECE9F2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Category Performance',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'See which categories are using the largest share of their budgets.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _performanceCount(
                    'Within budget',
                    withinBudget,
                    AppTheme.income,
                  ),
                ),
                Expanded(
                  child: _performanceCount(
                    'Near limit',
                    nearLimit,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _performanceCount(
                    'Reached / over',
                    reachedOrExceeded,
                    AppTheme.expense,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _performanceHighlight(
              label: 'Highest spending',
              category: highestSpending.budget.category,
              value: _formatCurrency(highestSpending.spent),
              detail:
                  '${highestSpending.utilizationPercentage.toStringAsFixed(1)}% of its budget used',
              color: AppTheme.primary,
              icon: Icons.trending_up,
            ),
            const SizedBox(height: 12),
            _performanceHighlight(
              label: 'Highest budget utilization',
              category: highestUtilization.budget.category,
              value:
                  '${highestUtilization.utilizationPercentage.toStringAsFixed(1)}%',
              detail: highestUtilization.status == BudgetStatus.exceeded
                  ? 'Above its monthly limit'
                  : highestUtilization.status == BudgetStatus.reached
                      ? 'Monthly limit reached'
                      : '${_formatCurrency(highestUtilization.remaining)} remaining',
              color: _statusColor(highestUtilization.status),
              icon: Icons.speed,
            ),
            const SizedBox(height: 16),
            const Text(
              'Utilization by category',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...ranked.map(_categoryPerformanceRow),
          ],
        ),
      ),
    );
  }

  Widget _performanceCount(String label, int count, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _performanceHighlight({
    required String label,
    required String category,
    required String value,
    required String detail,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  category,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryPerformanceRow(BudgetSummary summary) {
    final color = _statusColor(summary.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.budget.category,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '${summary.utilizationPercentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: summary.progressValue,
              minHeight: 7,
              backgroundColor: const Color(0xFFECE9F2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatCurrency(summary.spent)} spent of ${_formatCurrency(summary.monthlyLimit)}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetComparisonChart(TransactionProvider provider) {
    final summaries = provider.budgetSummaries();

    if (summaries.isEmpty) {
      return const SizedBox.shrink();
    }

    final largestValue = summaries.fold<double>(
      0,
      (currentMax, summary) {
        final categoryMax = summary.spent > summary.monthlyLimit
            ? summary.spent
            : summary.monthlyLimit;
        return categoryMax > currentMax ? categoryMax : currentMax;
      },
    );

    final maxY = largestValue <= 0 ? 100.0 : largestValue * 1.2;

    final groups = <BarChartGroupData>[];

    for (var index = 0; index < summaries.length; index++) {
      final summary = summaries[index];

      groups.add(
        BarChartGroupData(
          x: index,
          barsSpace: 5,
          barRods: [
            BarChartRodData(
              toY: summary.monthlyLimit,
              color: AppTheme.primary,
              width: 9,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
            BarChartRodData(
              toY: summary.spent,
              color: summary.isOverBudget
                  ? AppTheme.expense
                  : AppTheme.income,
              width: 9,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFECE9F2)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Budget vs Actual Spending',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Compare your monthly limits with actual expenses by category.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 260,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  groupsSpace: 16,
                  barGroups: groups,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: const Color(0xFFECE9F2),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();

                          if (index < 0 || index >= summaries.length) {
                            return const SizedBox.shrink();
                          }

                          return SideTitleWidget(
                            meta: meta,
                            space: 8,
                            child: SizedBox(
                              width: 62,
                              child: Text(
                                _shortCategoryName(
                                  summaries[index].budget.category,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final label = rodIndex == 0 ? 'Budget' : 'Actual';

                        return BarTooltipItem(
                          '$label\n${_formatCurrency(rod.toY)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _chartLegendItem(
                  color: AppTheme.primary,
                  label: 'Budget limit',
                ),
                _chartLegendItem(
                  color: AppTheme.income,
                  label: 'Actual spending',
                ),
                _chartLegendItem(
                  color: AppTheme.expense,
                  label: 'Actual over budget',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _shortCategoryName(String category) {
    switch (category) {
      case 'Food & Dining':
        return 'Food';
      case 'Bills & Utilities':
        return 'Bills';
      case 'Transportation':
        return 'Transport';
      default:
        return category;
    }
  }

  Widget _chartLegendItem({
    required Color color,
    required String label,
  }) {
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
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _monthlyOverviewCard({
    required double totalBudget,
    required double totalSpent,
    required double totalRemaining,
    required int categoryCount,
    required int alertCount,
  }) {
    final utilization = totalBudget <= 0
        ? 0.0
        : (totalSpent / totalBudget) * 100;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFECE9F2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Budget Overview',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _overviewMetric(
                    'Categories',
                    categoryCount.toString(),
                    Icons.category_outlined,
                  ),
                ),
                Expanded(
                  child: _overviewMetric(
                    'Utilization',
                    '${utilization.toStringAsFixed(1)}%',
                    Icons.pie_chart_outline,
                  ),
                ),
                Expanded(
                  child: _overviewMetric(
                    'Alerts',
                    alertCount.toString(),
                    Icons.notifications_active_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Budget position',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                Text(
                  totalRemaining < 0
                      ? '${_formatCurrency(totalRemaining.abs())} over'
                      : '${_formatCurrency(totalRemaining)} available',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: totalRemaining < 0
                        ? AppTheme.expense
                        : AppTheme.income,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewMetric(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primary, size: 19),
        const SizedBox(height: 7),
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _budgetAlertsSection(TransactionProvider provider) {
    final overBudget = provider.overBudgetCategories;
    final warnings = provider.warningBudgetCategories;
    final hasAlerts = overBudget.isNotEmpty || warnings.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Budget Alerts',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (!hasAlerts)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFECE9F2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppTheme.income),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You are on track. No categories are near or over their budget limits.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ...overBudget.map((summary) {
          final isExceeded = summary.status == BudgetStatus.exceeded;

          final message = isExceeded
              ? 'Exceeded by ${_formatCurrency(-summary.remaining)}'
              : 'You have used 100% of this category budget.';

          return _alertTile(
            title: summary.budget.category,
            message: message,
            color: AppTheme.expense,
            icon: Icons.error_outline,
          );
        }),
        ...warnings.map((summary) {
          return _alertTile(
            title: summary.budget.category,
            message:
                '${summary.utilizationPercentage.toStringAsFixed(1)}% used — ${_formatCurrency(summary.remaining)} remaining.',
            color: Colors.orange,
            icon: Icons.warning_amber_rounded,
          );
        }),
      ],
    );
  }

  Widget _alertTile({
    required String title,
    required String message,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 5),
        Text(
          _formatCurrency(amount),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Monthly report for a selected month.
/// Historical budget-limit changes are not stored separately.
class _MonthlyBudgetReport extends StatefulWidget {
  const _MonthlyBudgetReport();

  @override
  State<_MonthlyBudgetReport> createState() => _MonthlyBudgetReportState();
}

class _MonthlyBudgetReportState extends State<_MonthlyBudgetReport> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(amount);
  }

  List<DateTime> _availableMonths() {
    final now = DateTime.now();

    return List.generate(
      12,
      (index) => DateTime(now.year, now.month - index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final summaries = provider.budgetSummaries(month: _selectedMonth);

    final totalBudget = summaries.fold<double>(
      0,
      (sum, summary) => sum + summary.monthlyLimit,
    );

    final totalSpent = summaries.fold<double>(
      0,
      (sum, summary) => sum + summary.spent,
    );

    final remaining = totalBudget - totalSpent;

    final overBudgetCount = summaries
        .where((summary) =>
            summary.status == BudgetStatus.exceeded ||
            summary.status == BudgetStatus.reached)
        .length;

    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFECE9F2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Monthly Budget Report',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                DropdownButton<DateTime>(
                  value: _selectedMonth,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(12),
                  items: _availableMonths().map((month) {
                    return DropdownMenuItem<DateTime>(
                      value: month,
                      child: Text(
                        DateFormat('MMM yyyy').format(month),
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (month) {
                    if (month != null) {
                      setState(() => _selectedMonth = month);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Summary for $monthLabel',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _reportMetric(
                    'Budget',
                    _formatCurrency(totalBudget),
                  ),
                ),
                Expanded(
                  child: _reportMetric(
                    'Spent',
                    _formatCurrency(totalSpent),
                  ),
                ),
                Expanded(
                  child: _reportMetric(
                    remaining < 0 ? 'Over' : 'Remaining',
                    _formatCurrency(remaining.abs()),
                    valueColor:
                        remaining < 0 ? AppTheme.expense : AppTheme.income,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: totalBudget <= 0
                    ? 0
                    : (totalSpent / totalBudget).clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                backgroundColor: const Color(0xFFECE9F2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  remaining < 0 ? AppTheme.expense : AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  totalBudget <= 0
                      ? 'No budgets configured'
                      : '${(totalSpent / totalBudget * 100).toStringAsFixed(1)}% utilized',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '$overBudgetCount categories at or over limit',
                  style: TextStyle(
                    color: overBudgetCount > 0
                        ? AppTheme.expense
                        : AppTheme.income,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Category breakdown',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (summaries.isEmpty)
              const Text(
                'No budgets are configured for this report.',
                style: TextStyle(color: AppTheme.textSecondary),
              )
            else
              ...summaries.map(_reportCategoryRow),
            const SizedBox(height: 4),
            const Text(
              'Note: This report uses your currently configured monthly budget limits for the selected month.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportMetric(
    String label,
    String value, {
    Color valueColor = AppTheme.textPrimary,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportCategoryRow(BudgetSummary summary) {
    final color = switch (summary.status) {
      BudgetStatus.normal => AppTheme.income,
      BudgetStatus.warning => Colors.orange,
      BudgetStatus.reached || BudgetStatus.exceeded => AppTheme.expense,
    };

    final statusText = switch (summary.status) {
      BudgetStatus.normal => 'Within budget',
      BudgetStatus.warning => 'Near limit',
      BudgetStatus.reached => 'Limit reached',
      BudgetStatus.exceeded => 'Over budget',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.budget.category,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${_formatCurrency(summary.spent)} / ${_formatCurrency(summary.monthlyLimit)}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: summary.progressValue,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFECE9F2),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                statusText,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
