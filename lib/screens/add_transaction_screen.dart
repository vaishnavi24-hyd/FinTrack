
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController =
      TextEditingController();

  final TextEditingController _amountController =
      TextEditingController();

  String transactionType = 'Expense';

  DateTime selectedDate = DateTime.now();

  String selectedCategory = 'Food & Dining';

  final Map<String, List<String>> categories = {
    'Income': [
      'Salary',
      'Freelance',
      'Business',
      'Investment',
      'Other',
    ],
    'Expense': [
      'Food & Dining',
      'Shopping',
      'Transportation',
      'Bills & Utilities',
      'Entertainment',
      'Healthcare',
      'Education',
      'Other',
    ],
  };

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  void _changeTransactionType(String type) {
    setState(() {
      transactionType = type;
      selectedCategory = categories[type]!.first;
    });
  }

  Future<void> saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final transaction = TransactionModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      category: selectedCategory,
      amount: double.parse(_amountController.text.trim()),
      date: selectedDate,
      isIncome: transactionType == 'Income',
    );

    try {
      await context
          .read<TransactionProvider>()
          .addTransaction(transaction);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction added successfully!'),
        ),
      );

      _titleController.clear();
      _amountController.clear();

      setState(() {
        transactionType = 'Expense';
        selectedDate = DateTime.now();
        selectedCategory = categories['Expense']!.first;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save transaction: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Add Transaction'),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New Transaction',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Enter the details of your transaction.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Income / Expense selection
                  Row(
                    children: [
                      Expanded(
                        child: _typeButton(
                          label: 'Income',
                          isSelected: transactionType == 'Income',
                          color: AppTheme.income,
                          onTap: () =>
                              _changeTransactionType('Income'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _typeButton(
                          label: 'Expense',
                          isSelected: transactionType == 'Expense',
                          color: AppTheme.expense,
                          onTap: () =>
                              _changeTransactionType('Expense'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _fieldLabel('Description'),

                  TextFormField(
                    controller: _titleController,
                    decoration: _inputDecoration(
                      'Enter transaction description',
                      Icons.description_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a description';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  _fieldLabel('Amount'),

                  TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _inputDecoration(
                      'Enter amount',
                      Icons.currency_rupee,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an amount';
                      }

                      final amount = double.tryParse(value.trim());

                      if (amount == null || amount <= 0) {
                        return 'Enter a valid amount greater than zero';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  _fieldLabel('Category'),

                  DropdownButtonFormField<String>(
                    key: ValueKey(transactionType),
                    initialValue: selectedCategory,
                    decoration: _inputDecoration(
                      'Select category',
                      Icons.category_outlined,
                    ),
                    items: categories[transactionType]!
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedCategory = value;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 20),

                  _fieldLabel('Date'),

                  InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: _inputDecoration(
                        'Select date',
                        Icons.calendar_today_outlined,
                      ),
                      child: Text(
                        '${selectedDate.day.toString().padLeft(2, '0')}/'
                        '${selectedDate.month.toString().padLeft(2, '0')}/'
                        '${selectedDate.year}',
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: saveTransaction,
                      child: const Text(
                        'Save Transaction',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String hint,
    IconData icon,
  ) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFE8E5F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppTheme.primary,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _typeButton({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : const Color(0xFFE8E5F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? color
                  : AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
