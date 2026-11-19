class WalletCategory {
  final int id;
  final String name;
  final String? icon;

  WalletCategory({required this.id, required this.name, this.icon});

  factory WalletCategory.fromJson(Map<String, dynamic> j) => WalletCategory(
        id: j['category_id'] as int,
        name: j['name'] as String,
        icon: j['icon'] as String?,
      );
}
