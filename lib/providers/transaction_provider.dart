import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';

class TransactionProvider with ChangeNotifier {
  List<Transaction> _transactions = [];
  List<Transaction> _recentTransactions = [];
  bool _isLoading = false;
  String? _error;
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  double _balance = 0.0;
  List<Map<String, dynamic>> _categories = [];

  List<Transaction> get transactions => _transactions;
  List<Transaction> get recentTransactions => _recentTransactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalIncome => _totalIncome;
  double get totalExpense => _totalExpense;
  double get balance => _balance;
  List<Map<String, dynamic>> get categories => _categories;

  final ApiService _apiService = ApiService();

  // Fetch transaction summary
  Future<void> fetchSummary() async {
    try {
      final response = await _apiService.getTransactionSummary();

      if (response.statusCode == 200) {
        final data = response.data;
        _totalIncome = (data['tot_inc'] is String)
            ? double.parse(data['tot_inc'])
            : (data['tot_inc'] as num).toDouble();
        _totalExpense = (data['tot_exp'] is String)
            ? double.parse(data['tot_exp'])
            : (data['tot_exp'] as num).toDouble();
        _balance = (data['net'] is String)
            ? double.parse(data['net'])
            : (data['net'] as num).toDouble();

        // Parse categories data
        if (data['cats'] != null && data['cats'] is List) {
          _categories = (data['cats'] as List)
              .map(
                (cat) => {
                  'cat': cat['cat']?.toString() ?? '',
                  'inc': (cat['inc'] is String)
                      ? double.parse(cat['inc'])
                      : (cat['inc'] as num).toDouble(),
                  'exp': (cat['exp'] is String)
                      ? double.parse(cat['exp'])
                      : (cat['exp'] as num).toDouble(),
                  'net': (cat['net'] is String)
                      ? double.parse(cat['net'])
                      : (cat['net'] as num).toDouble(),
                  'cnt': cat['cnt'] ?? 0,
                },
              )
              .toList();

          // Sort by absolute net value (highest first)
          _categories.sort(
            (a, b) => (b['net'] as double).abs().compareTo(
              (a['net'] as double).abs(),
            ),
          );
        }

        notifyListeners();
      }
    } on DioException catch (e) {
      print('Error fetching summary: ${e.response?.data}');
    } catch (e) {
      print('Error fetching summary: $e');
    }
  }

  // Fetch recent transactions
  Future<void> fetchRecentTransactions(int limit) async {
    try {
      final response = await _apiService.getRecentTransactions(limit);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data
            : response.data['transactions'] ?? [];
        _recentTransactions = data
            .map((json) => Transaction.fromJson(json))
            .toList();
        notifyListeners();
      }
    } on DioException catch (e) {
      print('Error fetching recent transactions: ${e.response?.data}');
    } catch (e) {
      print('Error fetching recent transactions: $e');
    }
  }

  // Fetch monthly transactions
  Future<void> fetchMonthlyTransactions(int month, int year) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getMonthlyTransactions(month, year);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data
            : response.data['transactions'] ?? [];
        _transactions = data.map((json) => Transaction.fromJson(json)).toList();
      }
    } on DioException catch (e) {
      // Handle Dio-specific errors and extract error message from gin.H
      if (e.response?.data != null) {
        _error =
            e.response?.data['error'] ??
            e.response?.data['message'] ??
            'Failed to load transactions';
      } else {
        _error = 'Failed to load transactions: ${e.message}';
      }
    } catch (e) {
      _error = 'Failed to load transactions: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch transactions
  Future<void> fetchTransactions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getTransactions();

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['transactions'];
        _transactions = data.map((json) => Transaction.fromJson(json)).toList();
      }
    } on DioException catch (e) {
      // Handle Dio-specific errors and extract error message from gin.H
      if (e.response?.data != null) {
        _error =
            e.response?.data['error'] ??
            e.response?.data['message'] ??
            'Failed to load transactions';
      } else {
        _error = 'Failed to load transactions: ${e.message}';
      }
    } catch (e) {
      _error = 'Failed to load transactions: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add transaction
  Future<bool> addTransaction(Transaction transaction) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.createTransaction(
        transaction.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final newTransaction = Transaction.fromJson(
          response.data['transaction'],
        );
        _transactions.insert(0, newTransaction);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      // Handle Dio-specific errors and extract error message from gin.H
      if (e.response?.data != null) {
        _error =
            e.response?.data['error'] ??
            e.response?.data['message'] ??
            'Failed to add transaction';
      } else {
        _error = 'Failed to add transaction: ${e.message}';
      }
    } catch (e) {
      _error = 'Failed to add transaction: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Delete transaction
  Future<bool> deleteTransaction(String id) async {
    try {
      final response = await _apiService.deleteTransaction(id);

      if (response.statusCode == 200) {
        _transactions.removeWhere((t) => t.id == id);
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      // Handle Dio-specific errors and extract error message from gin.H
      if (e.response?.data != null) {
        _error =
            e.response?.data['error'] ??
            e.response?.data['message'] ??
            'Failed to delete transaction';
      } else {
        _error = 'Failed to delete transaction: ${e.message}';
      }
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to delete transaction: ${e.toString()}';
      notifyListeners();
      return false;
    }
    return false;
  }
}
