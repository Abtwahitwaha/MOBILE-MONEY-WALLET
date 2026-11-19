import 'package:flutter/material.dart';

import '../../models/wallet_transaction.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/format.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/swipe_to_delete.dart';
import '../../widgets/transaction_tile.dart';
import 'transaction_details_screen.dart';
import 'transaction_form_screen.dart';

/// One screen design used for BOTH the Income tab and the Expenses tab:
/// a header with totals, the list of that type only, and an "Add" button in the type's colour.
class TypedTransactionsScreen extends StatefulWidget {
  final String type; // "Income" or "Expense"
  const TypedTransactionsScreen({super.key, required this.type});

  @override
  State<TypedTransactionsScreen> createState() => _TypedTransactionsScreenState();
}

class _TypedTransactionsScreenState extends State<TypedTransactionsScreen> {
  bool _loading = true;
  Object? _error;
  List<WalletTransaction> _items = [];

  bool get _isIncome => widget.type == 'Income';
  Color get _color => _isIncome ? AppColors.income : AppColors.expense;
  Color get _soft => _isIncome ? AppColors.incomeSoft : AppColors.expenseSoft;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final all = await ApiService.instance.getTransactions();
      if (!mounted) return;
      setState(() {
        _items = all.where((t) => t.type == widget.type).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _push(Widget page) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => page));
    if (changed == true && mounted) _load(silent: true);
  }

  double get _monthTotal {
    final now = DateTime.now();
    var total = 0.0;
    for (final t in _items) {
      final w = t.when;
      if (w != null && w.year == now.year && w.month == now.month) total += t.amount;
    }
    return total;
  }

  double get _allTimeTotal => _items.fold<double>(0, (s, t) => s + t.amount);

  @override
  Widget build(BuildContext context) {
    final title = _isIncome ? 'Income' : 'Expenses';
    return Scaffold(
      backgroundColor: AppColors.navy,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _color,
        foregroundColor: Colors.white,
        onPressed: () => _push(_isIncome ? const AddIncomeScreen() : const AddExpenseScreen()),
        icon: const Icon(Icons.add),
        label: Text(_isIncome ? 'Add income' : 'Add expense',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: _soft, shape: BoxShape.circle),
                        child: Icon(_isIncome ? Icons.south_west : Icons.north_east, color: _color, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Text(title,
                          style: const TextStyle(color: AppColors.snow, fontSize: 28, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _Figure(label: 'This month', value: _loading ? '...' : formatUgx(_monthTotal))),
                      Expanded(child: _Figure(label: 'All time', value: _loading ? '...' : formatUgx(_allTimeTotal))),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
                ),
                child: _buildList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(error: _error!, onRetry: _load);
    if (_items.isEmpty) {
      return EmptyState(
        icon: _isIncome ? Icons.south_west : Icons.north_east,
        color: _color,
        title: _isIncome ? 'No income recorded yet' : 'No expenses recorded yet',
        message: _isIncome ? 'Tap "Add income" to record money you received.' : 'Tap "Add expense" to record money you spent.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 100),
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Swipe a transaction to the left to delete it.',
                  style: TextStyle(fontSize: 12, color: AppColors.grey)),
            );
          }
          final t = _items[i - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SwipeToDelete(
              transaction: t,
              onDeleted: () {
                setState(() => _items.removeWhere((x) => x.id == t.id));
              },
              child: TransactionTile(t: t, onTap: () => _push(TransactionDetailsScreen(transaction: t))),
            ),
          );
        },
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  const _Figure({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.slate, fontSize: 13)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: const TextStyle(color: AppColors.snow, fontSize: 21, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
