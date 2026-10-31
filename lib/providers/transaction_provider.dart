import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/budget_model.dart';
import '../models/transaction_model.dart';

/// Budget health based on the percentage of the monthly limit used.
enum BudgetStatus {
  normal,
  warning,
  reached,
  exceeded,
}

/// Calculated budget information for one category and one month.
///
/// This is calculated from transactions and budgets; it is not separately
/// stored, so it always reflects the latest transaction data.
class BudgetSummary {
  final BudgetModel budget;
  final double spent;
  final double remaining;
  final double utilizationPercentage;
  final BudgetStatus status;

  const BudgetSummary({
    required this.budget,
    required this.spent,
    required this.remaining,
    required this.utilizationPercentage,
    required this.status,
  });

  double get monthlyLimit => budget.monthlyLimit;

  /// A safe value for a progress indicator, which must stay between 0 and 1.
  double get progressValue =>
      (utilizationPercentage / 100).clamp(0.0, 1.0).toDouble();

  bool get isOverBudget => status == BudgetStatus.exceeded;
  bool get isAtOrOverBudget =>
      status == BudgetStatus.reached || status == BudgetStatus.exceeded;
  bool get isNearBudgetLimit => status == BudgetStatus.warning;
}

class TransactionProvider extends ChangeNotifier {
  static const String _transactionStorageKey = 'fintrack_transactions';
  static const String _budgetStorageKey = 'fintrack_budgets';

  List<TransactionModel> _transactions = [];
  List<BudgetModel> _budgets = [];

  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  // Return transactions sorted by newest date.
  List<TransactionModel> get transactions {
    final result = List<TransactionModel>.from(_transactions);
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  // Return all budgets.
  List<BudgetModel> get budgets =>
      List<BudgetModel>.unmodifiable(_budgets);

  // ============================================================
  // DATA LOADING
  // ============================================================

  Future<void> loadTransactions() async {
    final preferences = await SharedPreferences.getInstance();

    // Load transactions.
    final savedTransactions =
        preferences.getString(_transactionStorageKey);

    if (savedTransactions == null) {
      _loadSampleTransactions();
      await _saveTransactions();
    } else {
      try {
        final List<dynamic> decodedData =
            jsonDecode(savedTransactions);

        _transactions = decodedData.map((item) {
          return TransactionModel(
            id: item['id'] as String,
            title: item['title'] as String,
            category: item['category'] as String,
            amount: (item['amount'] as num).toDouble(),
            date: DateTime.parse(item['date'] as String),
            isIncome: item['isIncome'] as bool,
          );
        }).toList();
      } catch (e) {
        debugPrint('Error loading transactions: $e');
        _loadSampleTransactions();
        await _saveTransactions();
      }
    }

    // Load budgets.
    final savedBudgets = preferences.getString(_budgetStorageKey);

    if (savedBudgets == null) {
      _loadDefaultBudgets();
      await _saveBudgets();
    } else {
      try {
        final List<dynamic> decodedData = jsonDecode(savedBudgets);

        _budgets = decodedData.map((item) {
          return BudgetModel(
            id: item['id'] as String,
            category: item['category'] as String,
            monthlyLimit: (item['monthlyLimit'] as num).toDouble(),
          );
        }).toList();
      } catch (e) {
        debugPrint('Error loading budgets: $e');
        _loadDefaultBudgets();
        await _saveBudgets();
      }
    }

    _isLoaded = true;
    notifyListeners();
  }

  // ============================================================
  // DATA SAVING
  // ============================================================

  Future<void> _saveTransactions() async {
    final preferences = await SharedPreferences.getInstance();

    final encodedData = jsonEncode(
      _transactions.map((transaction) {
        return {
          'id': transaction.id,
          'title': transaction.title,
          'category': transaction.category,
          'amount': transaction.amount,
          'date': transaction.date.toIso8601String(),
          'isIncome': transaction.isIncome,
        };
      }).toList(),
    );

    await preferences.setString(
      _transactionStorageKey,
      encodedData,
    );
  }

  Future<void> _saveBudgets() async {
    final preferences = await SharedPreferences.getInstance();

    final encodedData = jsonEncode(
      _budgets.map((budget) {
        return {
          'id': budget.id,
          'category': budget.category,
          'monthlyLimit': budget.monthlyLimit,
        };
      }).toList(),
    );

    await preferences.setString(
      _budgetStorageKey,
      encodedData,
    );
  }

  // ============================================================
  // INITIAL SAMPLE DATA
  // ============================================================

  void _loadSampleTransactions() {
    final now = DateTime.now();

    _transactions = [
      TransactionModel(
        id: '1',
        title: 'Monthly Salary',
        category: 'Salary',
        amount: 45000,
        date: DateTime(now.year, now.month, 1),
        isIncome: true,
      ),
      TransactionModel(
        id: '2',
        title: 'Freelance Project',
        category: 'Freelance',
        amount: 5000,
        date: now.subtract(const Duration(days: 2)),
        isIncome: true,
      ),
      TransactionModel(
        id: '3',
        title: 'Grocery Shopping',
        category: 'Food & Dining',
        amount: 2500,
        date: now.subtract(const Duration(days: 1)),
        isIncome: false,
      ),
      TransactionModel(
        id: '4',
        title: 'Electricity Bill',
        category: 'Bills & Utilities',
        amount: 1800,
        date: now.subtract(const Duration(days: 3)),
        isIncome: false,
      ),
      TransactionModel(
        id: '5',
        title: 'Transportation',
        category: 'Transportation',
        amount: 2700,
        date: now.subtract(const Duration(days: 4)),
        isIncome: false,
      ),
      TransactionModel(
        id: '6',
        title: 'Shopping',
        category: 'Shopping',
        amount: 8000,
        date: now.subtract(const Duration(days: 5)),
        isIncome: false,
      ),
    ];
  }

  void _loadDefaultBudgets() {
    const defaultLimits = {
      'Food & Dining': 8000.0,
      'Shopping': 6000.0,
      'Transportation': 4000.0,
      'Entertainment': 3000.0,
      'Healthcare': 3000.0,
      'Education': 5000.0,
      'Bills & Utilities': 5000.0,
      'Other': 2000.0,
    };

    _budgets = defaultLimits.entries.map((entry) {
      return BudgetModel(
        id: 'budget_${entry.key.toLowerCase().replaceAll(' ', '_')}',
        category: entry.key,
        monthlyLimit: entry.value,
      );
    }).toList();
  }

  // ============================================================
  // TRANSACTION MANAGEMENT
  // ============================================================

  // Add a transaction.
  Future<void> addTransaction(TransactionModel transaction) async {
    _transactions.add(transaction);

    notifyListeners();

    await _saveTransactions();
  }

  // Update an existing transaction.
  Future<void> updateTransaction(
    TransactionModel updatedTransaction,
  ) async {
    final index = _transactions.indexWhere(
      (transaction) => transaction.id == updatedTransaction.id,
    );

    if (index == -1) return;

    _transactions[index] = updatedTransaction;

    notifyListeners();

    await _saveTransactions();
  }

  // Delete a transaction.
  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere(
      (transaction) => transaction.id == id,
    );

    notifyListeners();

    await _saveTransactions();
  }

  // ============================================================
  // BUDGET MANAGEMENT
  // ============================================================

  // Add a budget.
  Future<void> addBudget(BudgetModel budget) async {
    _budgets.add(budget);

    notifyListeners();

    await _saveBudgets();
  }

  // Update an existing budget.
  Future<void> updateBudget(BudgetModel updatedBudget) async {
    final index = _budgets.indexWhere(
      (budget) => budget.id == updatedBudget.id,
    );

    if (index == -1) return;

    _budgets[index] = updatedBudget;

    notifyListeners();

    await _saveBudgets();
  }

  // Delete a budget.
  Future<void> deleteBudget(String id) async {
    _budgets.removeWhere(
      (budget) => budget.id == id,
    );

    notifyListeners();

    await _saveBudgets();
  }

  // ============================================================
  // ADVANCED BUDGET CALCULATIONS - PHASE 6.1
  // ============================================================

  /// Returns the expense total for a category in the specified month.
  ///
  /// If [month] is omitted, the current month is used.
  double categoryExpenseForMonth(
    String category, {
    DateTime? month,
  }) {
    final selectedMonth = month ?? DateTime.now();

    return _transactions
        .where((transaction) =>
            !transaction.isIncome &&
            transaction.category == category &&
            transaction.date.year == selectedMonth.year &&
            transaction.date.month == selectedMonth.month)
        .fold<double>(
          0.0,
          (sum, transaction) => sum + transaction.amount,
        );
  }

  /// Calculates budget usage and status for one budget in a given month.
  BudgetSummary budgetSummary(
    BudgetModel budget, {
    DateTime? month,
  }) {
    final spent = categoryExpenseForMonth(
      budget.category,
      month: month,
    );

    final limit = budget.monthlyLimit;
    final remaining = limit - spent;
    final utilization = limit <= 0 ? 0.0 : (spent / limit) * 100;

    final BudgetStatus status;
    if (spent > limit) {
      status = BudgetStatus.exceeded;
    } else if (spent >= limit) {
      status = BudgetStatus.reached;
    } else if (utilization >= 80) {
      status = BudgetStatus.warning;
    } else {
      status = BudgetStatus.normal;
    }

    return BudgetSummary(
      budget: budget,
      spent: spent,
      remaining: remaining,
      utilizationPercentage: utilization,
      status: status,
    );
  }

  /// Returns calculated summaries for all budgets in a given month.
  List<BudgetSummary> budgetSummaries({DateTime? month}) {
    final summaries = _budgets
        .map((budget) => budgetSummary(budget, month: month))
        .toList();

    // Show categories with the highest utilization first.
    summaries.sort(
      (a, b) => b.utilizationPercentage.compareTo(a.utilizationPercentage),
    );

    return summaries;
  }

  /// Total amount allocated across all configured monthly budgets.
  double get totalAllocatedBudget {
    return _budgets.fold<double>(
      0.0,
      (sum, budget) => sum + budget.monthlyLimit,
    );
  }

  /// Total expenses belonging to categories that have a configured budget.
  double get totalBudgetSpent {
    return budgetSummaries().fold<double>(
      0.0,
      (sum, summary) => sum + summary.spent,
    );
  }

  /// Remaining amount across configured budgets; may be negative on overspend.
  double get totalBudgetRemaining =>
      totalAllocatedBudget - totalBudgetSpent;

  /// Categories whose spending has reached or exceeded their limit.
  List<BudgetSummary> get overBudgetCategories =>
      budgetSummaries()
          .where((summary) => summary.isAtOrOverBudget)
          .toList();

  /// Categories that have used at least 80% but have not reached the limit.
  List<BudgetSummary> get warningBudgetCategories =>
      budgetSummaries()
          .where((summary) => summary.isNearBudgetLimit)
          .toList();

  // ============================================================
  // EXISTING FINANCIAL CALCULATIONS
  // ============================================================

  // Total income for the current month.
  double get totalIncome {
    final now = DateTime.now();

    return _transactions
        .where((transaction) =>
            transaction.isIncome &&
            transaction.date.year == now.year &&
            transaction.date.month == now.month)
        .fold(
          0.0,
          (sum, transaction) => sum + transaction.amount,
        );
  }

  // Total expenses for the current month.
  double get totalExpenses {
    final now = DateTime.now();

    return _transactions
        .where((transaction) =>
            !transaction.isIncome &&
            transaction.date.year == now.year &&
            transaction.date.month == now.month)
        .fold(
          0.0,
          (sum, transaction) => sum + transaction.amount,
        );
  }

  // Overall balance across all transactions.
  double get totalBalance {
    return _transactions.fold(
      0.0,
      (sum, transaction) =>
          sum +
          (transaction.isIncome
              ? transaction.amount
              : -transaction.amount),
    );
  }

  // Current-month savings.
  double get monthlySavings => totalIncome - totalExpenses;

  // Current-month savings percentage.
  double get savingsPercentage {
    if (totalIncome == 0) return 0;

    return (monthlySavings / totalIncome) * 100;
  }

  // Existing current-month category expense method.
  // Kept unchanged so existing screens continue to work.
  double categoryExpense(String category) {
    return categoryExpenseForMonth(category);
  }

  // Weekly expenses from Monday to Sunday.
  List<double> get weeklyExpenses {
    final now = DateTime.now();

    final monday = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
    );

    return List.generate(7, (index) {
      final day = monday.add(Duration(days: index));

      return _transactions
          .where((transaction) =>
              !transaction.isIncome &&
              transaction.date.year == day.year &&
              transaction.date.month == day.month &&
              transaction.date.day == day.day)
          .fold(
            0.0,
            (sum, transaction) => sum + transaction.amount,
          );
    });
  }
}
