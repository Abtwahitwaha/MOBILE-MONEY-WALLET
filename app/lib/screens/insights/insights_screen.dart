import 'package:flutter/material.dart';

import '../../models/wallet_transaction.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/error_view.dart';
import '../../widgets/square_button.dart';

/// "Tracking by day" screen of the design, plus "spending by category".
/// Everything is calculated from the user's transactions, no extra backend call needed.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late Future<List<WalletTransaction>> _future = ApiService.instance.getTransactions();
  int _days = 7;

  void _reload() {
    setState(() {
      _future = ApiService.instance.getTransactions();
    });
  }

  String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<WalletTransaction>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
            return _buildContent(snap.data!);
          },
        ),
      ),
    );
  }

  Widget _buildContent(List<WalletTransaction> txs) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final start = end.subtract(Duration(days: _days - 1));
    final days = [for (var i = 0; i < _days; i++) start.add(Duration(days: i))];

    final expenseByDay = <String, double>{};
    final incomeByDay = <String, double>{};
    final byCategory = <String, double>{};
    var totalExpense = 0.0;
    var totalIncome = 0.0;

    for (final t in txs) {
      final w = t.when;
      if (w == null) continue;
      final day = DateTime(w.year, w.month, w.day);
      if (day.isBefore(start) || day.isAfter(end)) continue;
      final k = _key(day);
      if (t.isIncome) {
        incomeByDay[k] = (incomeByDay[k] ?? 0) + t.amount;
        totalIncome += t.amount;
      } else {
        expenseByDay[k] = (expenseByDay[k] ?? 0) + t.amount;
        totalExpense += t.amount;
        byCategory[t.categoryName] = (byCategory[t.categoryName] ?? 0) + t.amount;
      }
    }

    var maxDay = 0.0;
    for (final d in days) {
      final v = expenseByDay[_key(d)] ?? 0;
      if (v > maxDay) maxDay = v;
    }
    final saved = totalIncome - totalExpense;
    final categories = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final activeDays = days.where((d) => expenseByDay.containsKey(_key(d)) || incomeByDay.containsKey(_key(d))).toList();

    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        try {
          await _future;
        } catch (_) {}
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Row(
            children: [
              SquareIconButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 18),
          const Text('TRACKING BY DAY',
              style: TextStyle(color: AppColors.blue, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(rangeLabel(start, end), style: const TextStyle(color: AppColors.blue, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final d in const [7, 14, 30])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _days = d),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _days == d ? AppColors.navy : AppColors.paleBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$d days',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _days == d ? Colors.white : AppColors.navyDark)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Figure(label: 'TOTAL EXPENSES', value: formatUgx(totalExpense))),
              Expanded(child: _Figure(label: 'MONEY SAVED', value: formatUgx(saved))),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Money saved = income minus expenses in this period.',
              style: TextStyle(fontSize: 12, color: AppColors.grey)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(40)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Text('Detailed expense\namount',
                      style: TextStyle(color: Colors.white, fontSize: 20, height: 1.2)),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 175,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final d in days)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: _days > 14 ? 1 : 3),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  height: maxDay == 0
                                      ? 4.0
                                      : (4.0 + 136.0 * ((expenseByDay[_key(d)] ?? 0) / maxDay)),
                                  decoration: BoxDecoration(
                                    color: (expenseByDay[_key(d)] ?? 0) > 0 ? Colors.white : const Color(0x55FFFFFF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 14,
                                  child: FittedBox(
                                    child: Text(_days <= 7 ? dayShort(d) : '${d.day}',
                                        style: const TextStyle(color: Color(0xFF8FB8F0), fontSize: 11)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (activeDays.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 96,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final d in activeDays.reversed)
                          Container(
                            width: 118,
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('${dayShort(d)} ${d.day} ${monthShort(d.month)}',
                                    style: const TextStyle(color: AppColors.blue, fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('-${formatUgx(expenseByDay[_key(d)] ?? 0, prefix: false)}',
                                    style: const TextStyle(color: AppColors.blue, fontSize: 15)),
                                Text('+${formatUgx(incomeByDay[_key(d)] ?? 0, prefix: false)}',
                                    style: const TextStyle(color: AppColors.blue, fontSize: 15)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Text('Spending by category',
              style: TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (categories.isEmpty)
            const Text('No expenses in this period yet.', style: TextStyle(color: AppColors.grey))
          else
            for (final c in categories)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(c.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                        Text(formatUgx(c.value), style: const TextStyle(fontSize: 15, color: AppColors.navy)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: totalExpense == 0 ? 0 : c.value / totalExpense,
                        minHeight: 10,
                        backgroundColor: AppColors.paleBlue,
                        color: AppColors.blue,
                      ),
                    ),
                  ],
                ),
              ),
        ],
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
        Text(label, style: const TextStyle(color: AppColors.blue, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: const TextStyle(color: AppColors.blue, fontSize: 22, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
