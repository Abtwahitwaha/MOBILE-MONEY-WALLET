class Account {
  final int id;
  final String provider;
  final String phoneNumber;
  final String accountName;
  final double balance;
  final double openingBalance;
  final String? createdAt;

  Account({
    required this.id,
    required this.provider,
    required this.phoneNumber,
    required this.accountName,
    required this.balance,
    required this.openingBalance,
    this.createdAt,
  });

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['account_id'] as int,
        provider: j['provider'] as String,
        phoneNumber: j['phone_number'] as String,
        accountName: j['account_name'] as String,
        balance: (j['balance'] as num).toDouble(),
        openingBalance: (j['opening_balance'] as num).toDouble(),
        createdAt: j['created_at'] as String?,
      );

  /// "Since 11/26" style text for the card.
  String get since {
    final d = createdAt == null ? null : DateTime.tryParse(createdAt!);
    if (d == null) return '';
    return 'Since ${d.month.toString().padLeft(2, '0')}/${(d.year % 100).toString().padLeft(2, '0')}';
  }
}
