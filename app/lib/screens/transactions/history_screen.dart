import 'package:flutter/material.dart';

import '../../models/wallet_transaction.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/format.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/square_button.dart';
import '../../widgets/swipe_to_delete.dart';
import '../../widgets/transaction_tile.dart';
import 'transaction_details_screen.dart';

/// All transactions together, with period / type filters and search.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _loading = true;
  Object? _error;
  List<WalletTransaction> _all = [];
  String _type = 'All'; // All, Income, Expense
  String _period = 'Month'; // Today, Week, Month, All
  String _query = '';

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
      final data = await ApiService.instance.getTransactions();
      if (!mounted) return;
      setState(() {
        _all = data;
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

  bool _inPeriod(WalletTransaction t) {
    if (_period == 'All') return true;
    final w = t.when;
    if (w == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(w.year, w.month, w.day);
    switch (_period) {
      case 'Today':
        return day == today;
      case 'Week':
        return !day.isBefore(today.subtract(const Duration(days: 6))) && !day.isAfter(today);
      case 'Month':
        return w.year == now.year && w.month == now.month;
    }
    return true;
  }

  Future<void> _openDetails(WalletTransaction t) async {
    final changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => TransactionDetailsScreen(transaction: t)));
    if (changed == true && mounted) _load(silent: true);
  }

  String get _periodTitle {
    switch (_period) {
      case 'Today':
        return 'today';
      case 'Week':
        return 'the last 7 days';
      case 'Month':
        return 'this month';
    }
    return 'all time';
  }

  @override
  Widget build(BuildContext context) {
    final inPeriod = _all.where(_inPeriod).toList();
    final spent = inPeriod.where((t) => !t.isIncome).fold<double>(0, (s, t) => s + t.amount);
    final income = inPeriod.where((t) => t.isIncome).fold<double>(0, (s, t) => s + t.amount);
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SquareIconButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                      const Expanded(
                        child: Text('History',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.snow, fontSize: 24, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 52),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _Summary(
                          label: 'INCOME',
                          value: _loading ? '...' : formatUgx(income),
                          icon: Icons.south_west,
                          color: AppColors.income,
                        ),
                      ),
                      Expanded(
                        child: _Summary(
                          label: 'EXPENSES',
                          value: _loading ? '...' : formatUgx(spent),
                          icon: Icons.north_east,
                          color: AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Totals for $_periodTitle', style: const TextStyle(color: AppColors.slate, fontSize: 12)),
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
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(error: _error!, onRetry: _load);

    final q = _query.trim().toLowerCase();
    final shown = _all.where((t) {
      if (!_inPeriod(t)) return false;
      if (_type == 'Income' && !t.isIncome) return false;
      if (_type == 'Expense' && t.isIncome) return false;
      if (q.isNotEmpty) {
        final text = '${t.title} ${t.categoryName} ${t.accountName}'.toLowerCase();
        if (!text.contains(q)) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final p in const ['Today', 'Week', 'Month', 'All'])
                      _FilterChip(label: p, selected: _period == p, onTap: () => setState(() => _period = p)),
                    const SizedBox(width: 10),
                    _FilterChip(
                      label: 'All types',
                      selected: _type == 'All',
                      onTap: () => setState(() => _type = 'All'),
                    ),
                    _FilterChip(
                      label: 'Income',
                      selected: _type == 'Income',
                      color: AppColors.income,
                      onTap: () => setState(() => _type = 'Income'),
                    ),
                    _FilterChip(
                      label: 'Expense',
                      selected: _type == 'Expense',
                      color: AppColors.expense,
                      onTap: () => setState(() => _type = 'Expense'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search transactions',
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: AppColors.softBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('${shown.length} transaction${shown.length == 1 ? '' : 's'}  -  swipe left to delete',
                  style: const TextStyle(color: AppColors.grey, fontSize: 13)),
              const SizedBox(height: 10),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'Nothing found',
                  message: 'No transactions match these filters.',
                )
              : RefreshIndicator(
                  onRefresh: () => _load(silent: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final t = shown[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SwipeToDelete(
                          transaction: t,
                          onDeleted: () => setState(() => _all.removeWhere((x) => x.id == t.id)),
                          child: TransactionTile(t: t, onTap: () => _openDetails(t)),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Summary({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.slate, fontSize: 12, letterSpacing: 1)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style: const TextStyle(color: AppColors.snow, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color = AppColors.navy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : AppColors.paleBlue,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: selected ? Colors.white : AppColors.navyDark, fontSize: 14)),
        ),
      ),
    );
  }
}
