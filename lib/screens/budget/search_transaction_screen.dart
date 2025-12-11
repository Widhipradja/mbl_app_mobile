import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction.dart';
import '../../widgets/transaction_card.dart';

class SearchTransactionScreen extends StatefulWidget {
  const SearchTransactionScreen({super.key});

  @override
  State<SearchTransactionScreen> createState() =>
      _SearchTransactionScreenState();
}

class _SearchTransactionScreenState extends State<SearchTransactionScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategory;
  String? _selectedPic;
  String _filterType = 'all';
  DateTimeRange? _dateRange;
  List<Transaction> _searchResults = [];
  bool _hasSearched = false;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    setState(() {
      _isSearching = true;
    });

    try {
      final transactionProvider = context.read<TransactionProvider>();

      // Build query parameters
      String? category =
          (_selectedCategory != null && _selectedCategory != 'all')
          ? _selectedCategory
          : null;

      String? pic = (_selectedPic != null && _selectedPic != 'all')
          ? _selectedPic
          : null;

      String? trxType = _filterType != 'all' ? _filterType : null;

      String? description = _searchController.text.isNotEmpty
          ? _searchController.text
          : null;

      String? startDate;
      String? endDate;
      if (_dateRange != null) {
        startDate = DateFormat('yyyy-MM-dd').format(_dateRange!.start);
        endDate = DateFormat('yyyy-MM-dd').format(_dateRange!.end);
      }

      // Call API
      final results = await transactionProvider.inquiryTransactions(
        category: category,
        pic: pic,
        trxType: trxType,
        description: description,
        startDate: startDate,
        endDate: endDate,
      );

      // Sort results by date (newest first)
      results.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _searchResults = results;
        _hasSearched = true;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _hasSearched = true;
        _searchResults = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching transactions: $e')),
        );
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategory = null;
      _selectedPic = null;
      _filterType = 'all';
      _dateRange = null;
      _searchResults = [];
      _hasSearched = false;
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  void _showCategoryDialog(List<String> categories) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Category'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('All Categories'),
                onTap: () {
                  setState(() => _selectedCategory = 'all');
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ...categories.map(
                (cat) => ListTile(
                  title: Text(cat),
                  onTap: () {
                    setState(() => _selectedCategory = cat);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPicDialog(List<String> pics) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select PIC'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('All PIC'),
                onTap: () {
                  setState(() => _selectedPic = 'all');
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ...pics.map(
                (pic) => ListTile(
                  title: Text(pic),
                  onTap: () {
                    setState(() => _selectedPic = pic);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Types'),
              onTap: () {
                setState(() => _filterType = 'all');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Income'),
              onTap: () {
                setState(() => _filterType = 'income');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Expense'),
              onTap: () {
                setState(() => _filterType = 'expense');
                Navigator.pop(context);
              },
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    final transactionProvider = context.watch<TransactionProvider>();

    final categories =
        transactionProvider.transactions.map((t) => t.category).toSet().toList()
          ..sort();

    final pics =
        transactionProvider.transactions
            .map((t) => t.pic)
            .where((pic) => pic != null && pic.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList()
          ..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Transactions'),
        actions: [
          if (_hasSearched)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear All',
              onPressed: _clearFilters,
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by description or remarks...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) => setState(() {}),
                  onSubmitted: (value) => _performSearch(),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text(
                          _selectedCategory == null
                              ? 'Category'
                              : _selectedCategory == 'all'
                              ? 'All Categories'
                              : _selectedCategory!,
                        ),
                        selected: _selectedCategory != null,
                        onSelected: (selected) {
                          _showCategoryDialog(categories);
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(
                          _selectedPic == null
                              ? 'PIC'
                              : _selectedPic == 'all'
                              ? 'All PIC'
                              : _selectedPic!,
                        ),
                        selected: _selectedPic != null,
                        onSelected: (selected) {
                          _showPicDialog(pics);
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(
                          _filterType == 'all'
                              ? 'All Types'
                              : _filterType == 'income'
                              ? 'Income'
                              : 'Expense',
                        ),
                        selected: _filterType != 'all',
                        onSelected: (selected) {
                          _showTypeDialog();
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(
                          _dateRange == null
                              ? 'Date Range'
                              : '${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}',
                        ),
                        selected: _dateRange != null,
                        onSelected: (selected) => _selectDateRange(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _performSearch,
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : !_hasSearched
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Enter search criteria and tap Search',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Clear filters'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _searchResults.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            '${_searchResults.length} result${_searchResults.length == 1 ? '' : 's'} found',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }
                      final transaction = _searchResults[index - 1];
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
                            _performSearch();
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
