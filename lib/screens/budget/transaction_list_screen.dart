import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction.dart';
import '../../widgets/transaction_card.dart';
import 'package:intl/intl.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  String _filterType = 'all'; // all, income, expense
  String? _selectedCategory;
  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().fetchMonthlyTransactions(
        _selectedMonth,
        _selectedYear,
      );
    });
  }

  Future<void> _showMonthYearPicker() async {
    final now = DateTime.now();
    int tempMonth = _selectedMonth;
    int tempYear = _selectedYear;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Month & Year'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Month Selector
                  DropdownButtonFormField<int>(
                    initialValue: tempMonth,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(12, (index) {
                      return DropdownMenuItem(
                        value: index + 1,
                        child: Text(
                          DateFormat('MMMM').format(DateTime(2024, index + 1)),
                        ),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          tempMonth = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Year Selector
                  DropdownButtonFormField<int>(
                    initialValue: tempYear,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(5, (index) {
                      final year = now.year - 2 + index;
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          tempYear = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedMonth = tempMonth;
                      _selectedYear = tempYear;
                    });
                    context
                        .read<TransactionProvider>()
                        .fetchMonthlyTransactions(
                          _selectedMonth,
                          _selectedYear,
                        );
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = context.watch<TransactionProvider>();

    List<Transaction> filteredTransactions = transactionProvider.transactions;

    // Filter by type
    if (_filterType == 'income') {
      filteredTransactions = filteredTransactions
          .where((t) => t.type == TransactionType.income)
          .toList();
    } else if (_filterType == 'expense') {
      filteredTransactions = filteredTransactions
          .where((t) => t.type == TransactionType.expense)
          .toList();
    }

    // Filter by category
    if (_selectedCategory != null && _selectedCategory != 'all') {
      filteredTransactions = filteredTransactions
          .where((t) => t.category == _selectedCategory)
          .toList();
    }

    // Sort by date (descending - newest first)
    filteredTransactions.sort((a, b) => b.date.compareTo(a.date));

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
        title: GestureDetector(
          onTap: _showMonthYearPicker,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  DateFormat(
                    'MMM yyyy',
                  ).format(DateTime(_selectedYear, _selectedMonth)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.calendar_today, size: 18),
            ],
          ),
        ),
        actions: [
          // Search icon
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Transactions',
            onPressed: () {
              context.push('/budget/search');
            },
          ),
          // Category filter
          PopupMenuButton<String>(
            icon: Icon(
              Icons.category,
              color: _selectedCategory != null && _selectedCategory != 'all'
                  ? Colors.blue
                  : null,
            ),
            tooltip: 'Filter by Category',
            onSelected: (value) {
              setState(() {
                _selectedCategory = value;
              });
            },
            itemBuilder: (context) {
              // Get unique categories from transactions
              final categories = transactionProvider.transactions
                  .map((t) => t.category)
                  .toSet()
                  .toList();
              categories.sort();

              return [
                const PopupMenuItem(
                  value: 'all',
                  child: Text('All Categories'),
                ),
                const PopupMenuDivider(),
                ...categories.map(
                  (category) =>
                      PopupMenuItem(value: category, child: Text(category)),
                ),
              ];
            },
          ),
          // Type filter
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
          return transactionProvider.fetchMonthlyTransactions(
            _selectedMonth,
            _selectedYear,
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
                          onEdit: () {
                            context.push(
                              '/budget/edit-transaction',
                              extra: transaction,
                            );
                          },
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
