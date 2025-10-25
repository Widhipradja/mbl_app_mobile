import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';

class TransactionProvider with ChangeNotifier {
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String? _error;

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalIncome => _transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpense => _transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get balance => totalIncome - totalExpense;

  final ApiService _apiService = ApiService();

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
      final response = await _apiService.createTransaction(transaction.toJson());
      
      if (response.statusCode == 201) {
        final newTransaction = Transaction.fromJson(response.data['transaction']);
        _transactions.insert(0, newTransaction);
        _isLoading = false;
        notifyListeners();
        return true;
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
    } catch (e) {
      _error = 'Failed to delete transaction: ${e.toString()}';
      notifyListeners();
      return false;
    }
    return false;
  }
}