
import 'package:flutter/material.dart';
import '../app/app_theme.dart';

class TransactionTile extends StatelessWidget {
  final String title;
  final String category;
  final String date;
  final String amount;
  final IconData icon;
  final bool isIncome;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.title,
    required this.category,
    required this.date,
    required this.amount,
    required this.icon,
    required this.isIncome,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final Color transactionColor =
        isIncome ? AppTheme.income : AppTheme.expense;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: transactionColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: transactionColor,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$category • $date',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          Text(
            '${isIncome ? '+' : '-'}$amount',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: transactionColor,
              fontSize: 14,
            ),
          ),

          if (onDelete != null)
            IconButton(
              tooltip: 'Delete transaction',
              icon: const Icon(
                Icons.delete_outline,
                size: 19,
                color: AppTheme.textSecondary,
              ),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
