
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../providers/app_settings_provider.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends State<TransactionHistoryScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  String _typeFilter = 'All';
  String _categoryFilter = 'All';
  String _sortOption = 'Newest first';

  DateTime? _startDate;
  DateTime? _endDate;

  static const List<String> _categories = [
    'Salary',
    'Freelance',
    'Business',
    'Investment',
    'Food & Dining',
    'Shopping',
    'Transportation',
    'Bills & Utilities',
    'Entertainment',
    'Healthcare',
    'Education',
    'Other',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Currency formatting.

  // ============================================================
  // SEARCH, FILTER AND SORT
  // ============================================================

  List<TransactionModel> _filteredTransactions(
    List<TransactionModel> transactions,
  ) {
    final query = _searchController.text.trim().toLowerCase();

    final result = transactions.where((transaction) {
      final matchesSearch =
          transaction.title.toLowerCase().contains(query);

      final matchesType = _typeFilter == 'All' ||
          (_typeFilter == 'Income' && transaction.isIncome) ||
          (_typeFilter == 'Expense' && !transaction.isIncome);

      final matchesCategory = _categoryFilter == 'All' ||
          transaction.category == _categoryFilter;

      final date = transaction.date;

      final matchesStartDate = _startDate == null ||
          !date.isBefore(
            DateTime(
              _startDate!.year,
              _startDate!.month,
              _startDate!.day,
            ),
          );

      final matchesEndDate = _endDate == null ||
          !date.isAfter(
            DateTime(
              _endDate!.year,
              _endDate!.month,
              _endDate!.day,
              23,
              59,
              59,
            ),
          );

      return matchesSearch &&
          matchesType &&
          matchesCategory &&
          matchesStartDate &&
          matchesEndDate;
    }).toList();

    switch (_sortOption) {
      case 'Oldest first':
        result.sort((a, b) => a.date.compareTo(b.date));
        break;

      case 'Highest amount':
        result.sort((a, b) => b.amount.compareTo(a.amount));
        break;

      case 'Lowest amount':
        result.sort((a, b) => a.amount.compareTo(b.amount));
        break;

      default:
        result.sort((a, b) => b.date.compareTo(a.date));
    }

    return result;
  }

  // ============================================================
  // DATE RANGE
  // ============================================================

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(
              start: _startDate!,
              end: _endDate!,
            )
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  // ============================================================
  // CLEAR FILTERS
  // ============================================================

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _typeFilter = 'All';
      _categoryFilter = 'All';
      _sortOption = 'Newest first';
      _startDate = null;
      _endDate = null;
    });
  }

  // ============================================================
  // EDIT TRANSACTION
  // ============================================================

  Future<void> _editTransaction(
    TransactionModel transaction,
  ) async {
    final transactionProvider = context.read<TransactionProvider>();

    await showDialog<void>(
      context: context,
      builder: (_) => _EditTransactionDialog(
        transaction: transaction,
        onSave: transactionProvider.updateTransaction,
      ),
    );
  }

  // ============================================================
  // DELETE TRANSACTION
  // ============================================================

  Future<void> _deleteTransaction(
    TransactionModel transaction,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Transaction?'),
          content: Text(
            'Delete "${transaction.title}" permanently?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: AppTheme.expense,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await context
          .read<TransactionProvider>()
          .deleteTransaction(transaction.id);
    }
  }

  // ============================================================
  // TRANSACTION CARD
  // ============================================================

  Widget _buildTransactionCard(
    TransactionModel transaction,
    AppSettingsProvider settings,
  ) {
    final color = transaction.isIncome
        ? AppTheme.income
        : AppTheme.expense;

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: Color(0xFFECE9F2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transaction information.
            Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(
                    transaction.isIncome
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    color: color,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        '${transaction.category} • '
                        '${DateFormat('dd MMM yyyy').format(transaction.date)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            const Divider(height: 1),

            const SizedBox(height: 8),

            // Amount and action buttons.
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${transaction.isIncome ? '+' : '-'}'
                    '${settings.formatAmount(transaction.amount)}',
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                IconButton(
                  tooltip: 'Edit transaction',
                  onPressed: () => _editTransaction(transaction),
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: AppTheme.primary,
                  ),
                ),

                IconButton(
                  tooltip: 'Delete transaction',
                  onPressed: () => _deleteTransaction(transaction),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppTheme.expense,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD SCREEN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final settings = context.watch<AppSettingsProvider>();

    final allTransactions = provider.transactions;

    final filteredTransactions =
        _filteredTransactions(allTransactions);

    return Scaffold(
      backgroundColor: AppTheme.background,

      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              children: [
                // Search and filter section.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search transactions...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                    });
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Type and category filters.
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 500;

                          final typeDropdown =
                              DropdownButtonFormField<String>(
                            initialValue: _typeFilter,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Type',
                              border: OutlineInputBorder(),
                            ),
                            items: ['All', 'Income', 'Expense']
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(item),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _typeFilter = value;
                                });
                              }
                            },
                          );

                          final categoryDropdown =
                              DropdownButtonFormField<String>(
                            initialValue: _categoryFilter,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                            items: ['All', ..._categories]
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(
                                      item,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _categoryFilter = value;
                                });
                              }
                            },
                          );

                          if (isNarrow) {
                            return Column(
                              children: [
                                typeDropdown,
                                const SizedBox(height: 10),
                                categoryDropdown,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: typeDropdown),
                              const SizedBox(width: 12),
                              Expanded(child: categoryDropdown),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 10),

                      // Date range and sorting.
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 500;

                          final dateButton = OutlinedButton.icon(
                            onPressed: _selectDateRange,
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              _startDate == null
                                  ? 'Select date range'
                                  : '${DateFormat('dd MMM yyyy').format(_startDate!)}'
                                      ' - ${DateFormat('dd MMM yyyy').format(_endDate!)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );

                          final sortDropdown =
                              DropdownButtonFormField<String>(
                            initialValue: _sortOption,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Sort by',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              'Newest first',
                              'Oldest first',
                              'Highest amount',
                              'Lowest amount',
                            ].map((item) {
                              return DropdownMenuItem(
                                value: item,
                                child: Text(
                                  item,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _sortOption = value;
                                });
                              }
                            },
                          );

                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                dateButton,
                                const SizedBox(height: 10),
                                sortDropdown,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: dateButton),
                              const SizedBox(width: 12),
                              Expanded(child: sortDropdown),
                            ],
                          );
                        },
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Clear filters'),
                        ),
                      ),
                    ],
                  ),
                ),

                // Transaction count.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Transaction History',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${filteredTransactions.length} records',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Transaction list.
                Expanded(
                  child: filteredTransactions.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 52,
                                color: AppTheme.textSecondary,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No matching transactions found',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            4,
                            16,
                            20,
                          ),
                          itemCount: filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final transaction =
                                filteredTransactions[index];

                            return _buildTransactionCard(transaction, settings);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditTransactionDialog extends StatefulWidget {
  final TransactionModel transaction;
  final Future<void> Function(TransactionModel) onSave;

  const _EditTransactionDialog({
    required this.transaction,
    required this.onSave,
  });

  @override
  State<_EditTransactionDialog> createState() =>
      _EditTransactionDialogState();
}

class _EditTransactionDialogState
    extends State<_EditTransactionDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late bool _isIncome;
  late String _category;
  late DateTime _date;

  bool _isSaving = false;

  static const List<String> _incomeCategories = [
    'Salary',
    'Freelance',
    'Business',
    'Investment',
    'Other',
  ];

  static const List<String> _expenseCategories = [
    'Food & Dining',
    'Shopping',
    'Transportation',
    'Bills & Utilities',
    'Entertainment',
    'Healthcare',
    'Education',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.transaction.title,
    );

    _amountController = TextEditingController(
      text: widget.transaction.amount.toString(),
    );

    _isIncome = widget.transaction.isIncome;
    _date = widget.transaction.date;

    final categories =
        _isIncome ? _incomeCategories : _expenseCategories;

    _category = categories.contains(widget.transaction.category)
        ? widget.transaction.category
        : categories.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final initialDate = _date.isAfter(now) ? now : _date;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: now,
    );

    if (picked != null && mounted) {
      setState(() {
        _date = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final updatedTransaction = TransactionModel(
      id: widget.transaction.id,
      title: _titleController.text.trim(),
      category: _category,
      amount: double.parse(_amountController.text.trim()),
      date: _date,
      isIncome: _isIncome,
    );

    try {
      await widget.onSave(updatedTransaction);

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update transaction: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = context.watch<AppSettingsProvider>().currencySymbol;
    final availableCategories =
        _isIncome ? _incomeCategories : _expenseCategories;

    return AlertDialog(
      title: const Text('Edit Transaction'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Income'),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Expense'),
                  ),
                ],
                selected: {_isIncome},
                onSelectionChanged: _isSaving
                    ? null
                    : (selection) {
                        setState(() {
                          _isIncome = selection.first;
                          _category = _isIncome
                              ? _incomeCategories.first
                              : _expenseCategories.first;
                        });
                      },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                enabled: !_isSaving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '$currencySymbol ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');
                  if (amount == null || !amount.isFinite || amount <= 0) {
                    return 'Enter a valid positive amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_isIncome),
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: availableCategories.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            _category = value;
                          });
                        }
                      },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Transaction date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(_date)),
                trailing: const Icon(Icons.calendar_month),
                onTap: _isSaving ? null : _selectDate,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveTransaction,
          child: _isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Changes'),
        ),
      ],
    );
  }
}

