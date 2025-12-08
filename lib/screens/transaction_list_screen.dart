import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../widgets/transaction_card.dart';
import 'package:intl/intl.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  String _filterType = 'all'; // all, income, expense

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      context.read<TransactionProvider>().fetchMonthlyTransactions(
        now.month,
        now.year,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = context.watch<TransactionProvider>();

    List<Transaction> filteredTransactions = transactionProvider.transactions;
    if (_filterType == 'income') {
      filteredTransactions = transactionProvider.transactions
          .where((t) => t.type == TransactionType.income)
          .toList();
    } else if (_filterType == 'expense') {
      filteredTransactions = transactionProvider.transactions
          .where((t) => t.type == TransactionType.expense)
          .toList();
    }

    // Group transactions by date
    Map<String, List<Transaction>> groupedTransactions = {};
    for (var transaction in filteredTransactions) {
      final dateKey = DateFormat('MMM dd, yyyy').format(transaction.date);
      if (!groupedTransactions.containsKey(dateKey)) {
        groupedTransactions[dateKey] = [];
      }
      groupedTransactions[dateKey]!.add(transaction);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Transactions - ${DateFormat('MMMM yyyy').format(DateTime.now())}',
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _filterType = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('All Transactions'),
              ),
              const PopupMenuItem(value: 'income', child: Text('Income Only')),
              const PopupMenuItem(
                value: 'expense',
                child: Text('Expense Only'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () {
          final now = DateTime.now();
          return transactionProvider.fetchMonthlyTransactions(
            now.month,
            now.year,
          );
        },
        child: transactionProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : filteredTransactions.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No transactions found',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: groupedTransactions.length,
                itemBuilder: (context, index) {
                  final dateKey = groupedTransactions.keys.elementAt(index);
                  final transactions = groupedTransactions[dateKey]!;
                  final dayTotal = transactions.fold<double>(
                    0.0,
                    (sum, t) =>
                        sum +
                        (t.type == TransactionType.income
                            ? t.amount
                            : -t.amount),
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dateKey,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              NumberFormat.currency(
                                locale: 'id_ID',
                                symbol: 'Rp ',
                                decimalDigits: 0,
                              ).format(dayTotal.abs()),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: dayTotal >= 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...transactions.map((transaction) {
                        return TransactionCard(
                          transaction: transaction,
                          onDelete: () async {
                            final confirmed = await _showDeleteConfirmation(
                              context,
                            );
                            if (confirmed == true) {
                              await transactionProvider.deleteTransaction(
                                transaction.id!,
                              );
                              // Refresh monthly transactions after delete
                              final now = DateTime.now();
                              await transactionProvider
                                  .fetchMonthlyTransactions(
                                    now.month,
                                    now.year,
                                  );
                            }
                          },
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text(
          'Are you sure you want to delete this transaction?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
