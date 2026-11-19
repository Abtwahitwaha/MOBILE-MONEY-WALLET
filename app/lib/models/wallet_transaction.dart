class WalletTransaction {
  final int id;
  final int accountId;
  final int categoryId;
  final String type; // "Income" or "Expense"
  final double amount;
  final String? description;
  final String? date;
  final String accountName;
  final String categoryName;

  WalletTransaction({
    required this.id,
    required this.accountId,
    required this.categoryId,
    required this.type,
    required this.amount,
    this.description,
    this.date,
    required this.accountName,
    required this.categoryName,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> j) => WalletTransaction(
        id: j['transaction_id'] as int,
        accountId: j['account_id'] as int,
        categoryId: j['category_id'] as int,
        type: j['type'] as String,
        amount: (j['amount'] as num).toDouble(),
        description: j['description'] as String?,
        date: j['transaction_date'] as String?,
        accountName: j['account_name'] as String,
        categoryName: j['category_name'] as String,
      );

  bool get isIncome => type == 'Income';

  DateTime? get when => date == null ? null : DateTime.tryParse(date!);

  /// What to show as the main line of a row.
  String get title => (description != null && description!.trim().isNotEmpty) ? description! : categoryName;

  /// "+50,000" or "-15,000" style needs the formatter, so only the sign lives here.
  String get sign => isIncome ? '+' : '-';
}
