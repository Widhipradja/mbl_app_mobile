enum TransactionType { income, expense }

class Transaction {
  final String? id;
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final String? subCategory;
  final DateTime date;
  final String? description;
  final String? pic;
  final String? remarks;
  final String? requestedBy;

  Transaction({
    this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    this.subCategory,
    required this.date,
    this.description,
    this.pic,
    this.remarks,
    this.requestedBy,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      title: json['title'] ?? json['description'] ?? '',
      amount: (json['amount'] is String)
          ? double.parse(json['amount'])
          : (json['amount'] as num).toDouble(),
      type: json['trx_type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      category: json['category'] ?? '',
      subCategory: json['sub_category'],
      date: json['requested_date'] != null
          ? DateTime.parse(json['requested_date'])
          : (json['date'] != null
                ? DateTime.parse(json['date'])
                : DateTime.now()),
      description: json['description'],
      pic: json['pic'],
      remarks: json['remarks'],
      requestedBy: json['requested_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount.toString(),
      'requested_date':
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'trx_type': type == TransactionType.income ? 'income' : 'expense',
      'description': description ?? '',
      'category': category,
      'sub_category': subCategory ?? '',
      if (pic != null && pic!.isNotEmpty) 'pic': pic,
    };
  }
}
