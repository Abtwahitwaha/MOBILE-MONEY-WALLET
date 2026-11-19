import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/user_profile.dart';
import '../../models/wallet_transaction.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/format.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/swipe_to_delete.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/user_avatar.dart';
import '../insights/insights_screen.dart';
import '../transactions/history_screen.dart';
import '../transactions/transaction_details_screen.dart';
import '../transactions/transaction_form_screen.dart';

/// Dashboard: total balance, this month's income and expenses, quick actions, recent transactions.
class HomeScreen extends StatefulWidget {
  final void Function(int tabIndex) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  Object? _error;
  UserProfile? _user;
  List<Account> _accounts = [];
  List<WalletTransaction> _transactions = [];

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
      final api = ApiService.instance;
      final results = await Future.wait<Object>([api.getMe(), api.getAccounts(), api.getTransactions()]);
      if (!mounted) return;
      setState(() {
        _user = results[0] as UserProfile;
        _accounts = results[1] as List<Account>;
        _transactions = results[2] as List<WalletTransaction>;
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

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _load(silent: true);
  }

  double _monthSum(bool income) {
    final now = DateTime.now();
    var total = 0.0;
    for (final t in _transactions) {
      final w = t.when;
      if (w != null && w.year == now.year && w.month == now.month && t.isIncome == income) total += t.amount;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final total = _accounts.fold<double>(0, (s, a) => s + a.balance);
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(greeting(),
                                style: const TextStyle(color: AppColors.snow, fontSize: 24, fontWeight: FontWeight.bold)),
                            if (_user != null)
                              Text(_user!.firstName, style: const TextStyle(color: AppColors.slate, fontSize: 15)),
                          ],
                        ),
                      ),
                      UserAvatar(size: 52, onTap: () => widget.onNavigate(4)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text('Total balance', style: TextStyle(color: AppColors.slate, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(_loading ? 'UGX ...' : formatUgx(total),
                      style: const TextStyle(color: AppColors.snow, fontSize: 34, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryChip(
                          label: 'Income this month',
                          amount: _loading ? '...' : formatUgx(_monthSum(true)),
                          icon: Icons.south_west,
                          color: AppColors.income,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryChip(
                          label: 'Expenses this month',
                          amount: _loading ? '...' : formatUgx(_monthSum(false)),
                          icon: Icons.north_east,
                          color: AppColors.expense,
                        ),
                      ),
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
                child: _buildSheet(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheet() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(error: _error!, onRetry: _load);

    final recent = _transactions.take(5).toList();
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        children: [
          const Text('Quick actions', style: TextStyle(color: AppColors.navy, fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _QuickAction(
                icon: Icons.south_west,
                label: 'Add\nincome',
                color: AppColors.income,
                soft: AppColors.incomeSoft,
                onTap: () => _open(const AddIncomeScreen()),
              ),
              _QuickAction(
                icon: Icons.north_east,
                label: 'Add\nexpense',
                color: AppColors.expense,
                soft: AppColors.expenseSoft,
                onTap: () => _open(const AddExpenseScreen()),
              ),
              _QuickAction(
                icon: Icons.receipt_long,
                label: 'History',
                color: AppColors.blue,
                soft: AppColors.softBlue,
                onTap: () => _open(const HistoryScreen()),
              ),
              _QuickAction(
                icon: Icons.insights,
                label: 'Insights',
                color: AppColors.blue,
                soft: AppColors.softBlue,
                onTap: () => _open(const InsightsScreen()),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              const Expanded(
                child: Text('Recent transactions',
                    style: TextStyle(color: AppColors.navy, fontSize: 19, fontWeight: FontWeight.bold)),
              ),
              TextButton(onPressed: () => _open(const HistoryScreen()), child: const Text('See all')),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Swipe a transaction to the left to delete it.', style: TextStyle(fontSize: 12, color: AppColors.grey)),
          const SizedBox(height: 10),
          if (_accounts.isEmpty)
            EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Add your first account',
              message: 'Add your MTN or Airtel wallet, then record your income.',
              buttonLabel: 'Add account',
              onPressed: () => widget.onNavigate(3),
            )
          else if (recent.isEmpty)
            EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No transactions yet',
              message: 'Record your first income or expense.',
              buttonLabel: 'Add income',
              onPressed: () => _open(const AddIncomeScreen()),
            )
          else
            for (final t in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SwipeToDelete(
                  transaction: t,
                  onDeleted: () {
                    setState(() => _transactions.removeWhere((x) => x.id == t.id));
                    _load(silent: true); // refresh the balance
                  },
                  child: TransactionTile(t: t, onTap: () => _open(TransactionDetailsScreen(transaction: t))),
                ),
              ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color color;
  const _SummaryChip({required this.label, required this.amount, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(18)),
      child: Row(
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
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.slate, fontSize: 11)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(amount,
                      style: const TextStyle(color: AppColors.snow, fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color soft;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.soft, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(20)),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.ink, fontSize: 13, fontWeight: FontWeight.w600, height: 1.15)),
          ],
        ),
      ),
    );
  }
}
