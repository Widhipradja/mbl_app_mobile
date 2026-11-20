import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/transaction_provider.dart';

import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../models/transaction.dart';
import '../../widgets/transaction_card.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:async';
import 'dart:io';
import 'package:flutter/rendering.dart';

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
  // Removed unused _receiptKey

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

  Future<String> _buildTransactionReceipt(
      BuildContext context, Transaction transaction) async {
    // Group name: read directly from the logged-in user's cached profile
    final budgetGroupName =
        StorageService.getUser()?.groupName?.trim() ?? '';

    // LOCATION and LOCATION_ADDR: fetch from BUDGET module config
    String budgetLocation = '';
    String budgetLocationAddr = '';

    Future<String> fetchBudgetCfg(String code) async {
      try {
        final api = ApiService();
        final resp = await api.getZakatConfigurationByModuleAndCode(
          'BUDGET',
          code,
        );
        final raw = resp.data;
        final map = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
        final payload = map['data'] is Map<String, dynamic>
            ? map['data'] as Map<String, dynamic>
            : map;
        return payload['value']?.toString().trim() ?? '';
      } catch (e) {
        debugPrint('_buildTransactionReceipt cfg[$code] error: $e');
        return '';
      }
    }

    // Fetch in parallel
    final results = await Future.wait([
      fetchBudgetCfg('LOCATION'),
      fetchBudgetCfg('LOCATION_ADDR'),
    ]);
    budgetLocation = results[0];
    budgetLocationAddr = results[1];
    const footerText = 'الحمد لله جزاك الله خيرا';

    final repaintKey = GlobalKey();
    final receiptWidget = RepaintBoundary(
      key: repaintKey,
      child: Material(
        color: Colors.transparent,
        child: _TransactionReceiptCard(
          transaction: transaction,
          orgName: budgetGroupName,
          location: budgetLocation,
          locationAddr: budgetLocationAddr,
          footerText: footerText,
        ),
      ),
    );

    late OverlayEntry entry;
    final completer = Completer<Uint8List>();
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -5000,
        top: -5000,
        width: 360,
        child: receiptWidget,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      try {
        final boundary = repaintKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary == null) {
          completer.completeError('No boundary');
          return;
        }
        final img = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        completer.complete(byteData!.buffer.asUint8List());
      } catch (e) {
        completer.completeError(e);
      } finally {
        entry.remove();
      }
    });
    if (context.mounted) {
      Overlay.of(context).insert(entry);
    } else {
      entry.remove();
      return '';
    }
    final bytes = await completer.future;
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/transaction_receipt_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<void> _sendTransactionReceipt(
      BuildContext context, Transaction transaction) async {
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF066046)),
                SizedBox(height: 12),
                Text('Membuat struk...', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final filePath = await _buildTransactionReceipt(context, transaction);
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (filePath.isEmpty) return;
      if (!context.mounted) return;
      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'image/png')],
        subject: 'Transaction Receipt',
        text: 'Transaction Receipt',
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuat struk gambar.')),
        );
      }
    }
  }

  Future<void> _showMonthYearPicker() async {
    int tempMonth = _selectedMonth;
    int tempYear = _selectedYear;
    final now = DateTime.now();

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
                    value: tempMonth,
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
                    value: tempYear,
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
                        Icon(Icons.receipt_long,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions found',
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[600]),
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
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TransactionCard(
                                    transaction: transaction,
                                    onEdit: () {
                                      context.push(
                                        '/budget/edit-transaction',
                                        extra: transaction,
                                      );
                                    },
                                    onDelete: () async {
                                      final confirmed =
                                          await _showDeleteConfirmation(
                                        context,
                                      );
                                      if (confirmed == true) {
                                        await transactionProvider
                                            .deleteTransaction(
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
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.receipt_long_rounded,
                                      color: Colors.green),
                                  tooltip: 'Kirim Struk',
                                  onPressed: () => _sendTransactionReceipt(
                                      context, transaction),
                                ),
                              ],
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

// ────────────────────────────────────────────────────────────────────────────
// Thermal-style receipt card for Budget Transactions
// Same structure as _ReceiptCard in muzakki_list_screen.dart:
//   • Green header (logo + title + org info)
//   • White body (rows + detail)
//   • Footer (closing note)
// ────────────────────────────────────────────────────────────────────────────
class _TransactionReceiptCard extends StatelessWidget {
  const _TransactionReceiptCard({
    required this.transaction,
    this.orgName = '',
    this.location = '',
    this.locationAddr = '',
    this.footerText = '',
  });

  final Transaction transaction;
  final String orgName;
  final String location;
  final String locationAddr;
  final String footerText;


  static const _green = Color(0xFF066046);
  static const _lightGreen = Color(0xFFE8F5F0);
  static const _textDark = Color(0xFF1A1A1A);
  static const _textMuted = Color(0xFF64748B);

  String _fmtDate(DateTime d) {
    const months = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  String _fmtRp(double v) =>
      'Rp ${v.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]!}.')}';

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final amountLabel = isIncome ? 'Pemasukan' : 'Pengeluaran';

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Green header ────────────────────────────────────────────
          Container(
            color: _green,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/icon/img_mbl.jpg',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
                // Title
                Text(
                  isIncome ? 'BUKTI PEMASUKAN' : 'BUKTI PENGELUARAN',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Kas & Keuangan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
                // Org / location block
                if (orgName.isNotEmpty ||
                    location.isNotEmpty ||
                    locationAddr.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (orgName.isNotEmpty)
                          Text(
                            orgName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        if (location.isNotEmpty) ...[
                          if (orgName.isNotEmpty) const SizedBox(height: 1),
                          Text(
                            location,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ],
                        if (locationAddr.isNotEmpty)
                          Text(
                            locationAddr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _separator(),
                _row('Tanggal', _fmtDate(transaction.date)),
                _row('Keterangan', transaction.title),

                _row('Jumlah', _fmtRp(transaction.amount)),
                if (transaction.pic != null && transaction.pic!.isNotEmpty)
                  _row('PIC', transaction.pic!),
                if (transaction.requestedBy != null &&
                    transaction.requestedBy!.isNotEmpty)
                  _row('Diterima oleh', transaction.requestedBy!),

                if (transaction.remarks != null &&
                    transaction.remarks!.isNotEmpty)
                  _row('Keterangan', transaction.remarks!),
                if (transaction.tags != null && transaction.tags!.isNotEmpty)
                  _row('Tags', transaction.tags!.join(', ')),
                _separator(),

                // ── Amount highlight ─────────────────────────────────
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: isIncome
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total $amountLabel',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isIncome
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFC62828),
                        ),
                      ),
                      Text(
                        _fmtRp(transaction.amount),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isIncome
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFC62828),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Footer note ──────────────────────────────────────
                if (footerText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _lightGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      footerText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _green,
                        height: 1.7,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Dashed separator line
  Widget _separator() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LayoutBuilder(
          builder: (_, constraints) {
            final dashCount = (constraints.maxWidth / 8).floor();
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                dashCount,
                (_) => Container(
                  width: 5,
                  height: 1,
                  color: const Color(0xFFCBD5E1),
                ),
              ),
            );
          },
        ),
      );

  /// Two-column label / value row
  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: _textMuted),
              ),
            ),
            const Text(': ', style: TextStyle(fontSize: 12, color: _textMuted)),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textDark,
                ),
              ),
            ),
          ],
        ),
      );
}
