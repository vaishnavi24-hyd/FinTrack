
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../providers/transaction_provider.dart';

/// Generates a detailed monthly financial report in PDF format.
///
/// Note: Historical budget limits are not stored separately.
/// Therefore, past reports use the currently configured budget limits.
class PdfReportService {
  static String _currency(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: 'Rs. ',
      decimalDigits: 2,
    ).format(amount);
  }

  static Future<void> exportMonthlyReport(
    TransactionProvider provider, {
    DateTime? month,
  }) async {
    final selectedMonth = month ?? DateTime.now();

    final start = DateTime(selectedMonth.year, selectedMonth.month);
    final end = DateTime(selectedMonth.year, selectedMonth.month + 1);

    final monthTransactions = provider.transactions.where((transaction) {
      return !transaction.date.isBefore(start) &&
          transaction.date.isBefore(end);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final incomeTransactions =
        monthTransactions.where((t) => t.isIncome).toList();

    final expenseTransactions =
        monthTransactions.where((t) => !t.isIncome).toList();

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

    final summaries = provider.budgetSummaries(month: selectedMonth);

    final totalBudget = summaries.fold<double>(
      0,
      (sum, summary) => sum + summary.monthlyLimit,
    );

    final budgetedCategorySpend = summaries.fold<double>(
      0,
      (sum, summary) => sum + summary.spent,
    );

    final remainingBudget = totalBudget - budgetedCategorySpend;

    final categoryTotals = <String, double>{};

    for (final transaction in expenseTransactions) {
      categoryTotals.update(
        transaction.category,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    final categoryEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final atOrOverLimit = summaries
        .where((summary) => summary.isAtOrOverBudget)
        .toList();

    final nearLimit = summaries
        .where((summary) => summary.isNearBudgetLimit)
        .toList();

    final generatedAt =
        DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    final monthLabel = DateFormat('MMMM yyyy').format(selectedMonth);

    final document = pw.Document(
      title: 'FinTrack Monthly Financial Report - $monthLabel',
      author: 'FinTrack',
      subject: 'Monthly income, expenses and budget performance',
    );

    final headerStyle = pw.TextStyle(
      fontSize: 20,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.deepPurple,
    );

    final sectionStyle = pw.TextStyle(
      fontSize: 13,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.deepPurple,
    );

    const smallStyle = pw.TextStyle(
      fontSize: 8,
      color: PdfColors.grey700,
    );

    pw.Widget sectionTitle(String title) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 7),
        child: pw.Text(title, style: sectionStyle),
      );
    }

    pw.Widget metric(String label, String value) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(9),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: smallStyle),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget dataTable(
      List<String> headers,
      List<List<String>> rows, {
      List<int>? flexes,
    }) {
      return pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        headerDecoration: const pw.BoxDecoration(
          color: PdfColors.deepPurple,
        ),
        cellStyle: const pw.TextStyle(fontSize: 8),
        cellPadding: const pw.EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 5,
        ),
        border: pw.TableBorder.all(
          color: PdfColors.grey300,
          width: 0.5,
        ),
        columnWidths: flexes == null
            ? null
            : {
                for (var i = 0; i < flexes.length; i++)
                  i: pw.FlexColumnWidth(flexes[i].toDouble()),
              },
      );
    }

    String budgetStatusLabel(dynamic summary) {
      switch (summary.status.toString().split('.').last) {
        case 'warning':
          return 'Near limit';
        case 'reached':
          return 'Limit reached';
        case 'exceeded':
          return 'Over budget';
        default:
          return 'Within budget';
      }
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 12),
            child: pw.Text(
              'FinTrack  |  Page ${context.pageNumber} of ${context.pagesCount}',
              style: smallStyle,
            ),
          );
        },
        build: (context) {
          return [
            pw.Text('FinTrack', style: headerStyle),
            pw.SizedBox(height: 3),
            pw.Text(
              'Monthly Financial Report',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Reporting period: $monthLabel', style: smallStyle),
            pw.Text('Generated: $generatedAt', style: smallStyle),

            // 1. Financial Summary
            sectionTitle('1. Financial Summary'),
            pw.Row(
              children: [
                pw.Expanded(
                  child: metric('Total income', _currency(totalIncome)),
                ),
                pw.SizedBox(width: 7),
                pw.Expanded(
                  child: metric('Total expenses', _currency(totalExpenses)),
                ),
              ],
            ),
            pw.SizedBox(height: 7),
            pw.Row(
              children: [
                pw.Expanded(
                  child: metric('Net savings', _currency(netSavings)),
                ),
                pw.SizedBox(width: 7),
                pw.Expanded(
                  child: metric(
                    'Savings rate',
                    '${savingsRate.toStringAsFixed(1)}%',
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 7),
            metric(
              'Overall balance (all recorded transactions)',
              _currency(provider.totalBalance),
            ),

            // 2. Income Breakdown
            sectionTitle('2. Income Breakdown'),
            if (incomeTransactions.isEmpty)
              pw.Text(
                'No income transactions recorded for this month.',
                style: smallStyle,
              )
            else
              dataTable(
                ['Date', 'Description', 'Category', 'Amount'],
                incomeTransactions.map((t) {
                  return [
                    DateFormat('dd MMM yyyy').format(t.date),
                    t.title,
                    t.category,
                    _currency(t.amount),
                  ];
                }).toList(),
                flexes: [2, 4, 3, 2],
              ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Total income: ${_currency(totalIncome)}',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
            ),

            // 3. Expense Breakdown
            sectionTitle('3. Expense Breakdown by Category'),
            if (categoryEntries.isEmpty)
              pw.Text(
                'No expense transactions recorded for this month.',
                style: smallStyle,
              )
            else
              dataTable(
                ['Category', 'Actual expenses'],
                categoryEntries.map((entry) {
                  return [
                    entry.key,
                    _currency(entry.value),
                  ];
                }).toList(),
                flexes: [4, 2],
              ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Total expenses: ${_currency(totalExpenses)}',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
            ),

            // 4. Budget Performance
            sectionTitle('4. Budget Performance'),
            pw.Row(
              children: [
                pw.Expanded(
                  child: metric(
                    'Allocated budget',
                    _currency(totalBudget),
                  ),
                ),
                pw.SizedBox(width: 7),
                pw.Expanded(
                  child: metric(
                    'Spent in budgeted categories',
                    _currency(budgetedCategorySpend),
                  ),
                ),
                pw.SizedBox(width: 7),
                pw.Expanded(
                  child: metric(
                    'Remaining / over',
                    _currency(remainingBudget),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            if (summaries.isEmpty)
              pw.Text('No budgets configured.', style: smallStyle)
            else
              dataTable(
                [
                  'Category',
                  'Budget',
                  'Spent',
                  'Remaining',
                  'Used',
                  'Status',
                ],
                summaries.map((summary) {
                  return [
                    summary.budget.category,
                    _currency(summary.monthlyLimit),
                    _currency(summary.spent),
                    _currency(summary.remaining),
                    '${summary.utilizationPercentage.toStringAsFixed(1)}%',
                    budgetStatusLabel(summary),
                  ];
                }).toList(),
                flexes: [3, 2, 2, 2, 1, 2],
              ),

            // 5. Budget Alerts
            sectionTitle('5. Budget Alerts'),
            if (atOrOverLimit.isEmpty && nearLimit.isEmpty)
              pw.Text(
                'No categories are near or over their budget limits.',
                style: smallStyle,
              ),
            ...atOrOverLimit.map((summary) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text(
                  '${summary.budget.category}: '
                  '${budgetStatusLabel(summary)}'
                  '${summary.isOverBudget ? ' by ${_currency(-summary.remaining)}' : ''}.',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              );
            }),
            ...nearLimit.map((summary) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text(
                  '${summary.budget.category}: '
                  '${summary.utilizationPercentage.toStringAsFixed(1)}% used, '
                  '${_currency(summary.remaining)} remaining.',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              );
            }),

            // 6. Complete Transaction Register
            sectionTitle('6. Complete Transaction Register'),
            if (monthTransactions.isEmpty)
              pw.Text(
                'No transactions recorded for this month.',
                style: smallStyle,
              )
            else
              dataTable(
                ['Date', 'Description', 'Category', 'Type', 'Amount'],
                monthTransactions.map((transaction) {
                  return [
                    DateFormat('dd MMM yyyy').format(transaction.date),
                    transaction.title,
                    transaction.category,
                    transaction.isIncome ? 'Income' : 'Expense',
                    _currency(transaction.amount),
                  ];
                }).toList(),
                flexes: [2, 4, 3, 2, 2],
              ),

            pw.SizedBox(height: 14),
            pw.Text('Report notes', style: sectionStyle),
            pw.SizedBox(height: 4),
            pw.Text(
              'Net savings = total income minus total expenses. '
              'Savings rate = net savings divided by income. '
              'The overall balance includes all transactions recorded in FinTrack, '
              'regardless of the selected reporting month. '
              'Budget comparisons use the currently configured monthly limits; '
              'historical budget-limit changes are not stored by the application.',
              style: smallStyle,
            ),
          ];
        },
      ),
    );

    final Uint8List bytes = await document.save();

    final fileName =
        'FinTrack_Monthly_Report_'
        '${DateFormat('yyyy_MM').format(selectedMonth)}.pdf';

    await Printing.sharePdf(
      bytes: bytes,
      filename: fileName,
    );
  }
}
