import '../models/wallet_category.dart';

/// The categories table has no "type" column, so the app decides on its own which
/// categories belong to income. Everything else is offered for expenses.
const String kOtherCategory = 'Other';
const Set<String> _incomeNames = {'salary', 'business income'};

bool isIncomeCategory(String name) => _incomeNames.contains(name.trim().toLowerCase());
bool isOtherCategory(String name) => name.trim().toLowerCase() == 'other';

/// Categories to show on the Add Income / Add Expense screens ("Other" is always last).
List<WalletCategory> categoriesForType(String type, List<WalletCategory> all, {int? keepId}) {
  final list = all.where((c) {
    if (c.id == keepId) return true; // keep the one already chosen when editing
    if (isOtherCategory(c.name)) return true;
    return type == 'Income' ? isIncomeCategory(c.name) : !isIncomeCategory(c.name);
  }).toList();
  list.sort((a, b) {
    if (isOtherCategory(a.name)) return 1;
    if (isOtherCategory(b.name)) return -1;
    return a.name.compareTo(b.name);
  });
  return list;
}
