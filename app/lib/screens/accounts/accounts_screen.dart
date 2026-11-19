import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/wallet_transaction.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../utils/provider_brand.dart';
import '../../widgets/account_card.dart';
import '../../widgets/app_notification.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/provider_logo.dart';

/// Mobile money accounts: provider-coloured cards (MTN yellow, Airtel red), monthly statistics,
/// and add / edit / delete. There is no initial deposit: new accounts start at UGX 0 and
/// money is added by recording Income.
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  bool _loading = true;
  Object? _error;
  List<Account> _accounts = [];
  List<WalletTransaction> _transactions = [];
  final PageController _pager = PageController(viewportFraction: 0.93);
  int _page = 0;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
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
      final results = await Future.wait<Object>([api.getAccounts(), api.getTransactions()]);
      if (!mounted) return;
      setState(() {
        _accounts = results[0] as List<Account>;
        _transactions = results[1] as List<WalletTransaction>;
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

  Future<void> _openForm([Account? existing]) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _AccountForm(existing: existing),
      ),
    );
    if (result == null) return;
    AppNotification.show(overlay, title: result, message: 'Your accounts were updated.', kind: NotificationKind.info);
    _load(silent: true);
  }

  Future<void> _delete(Account a) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final ok = await confirmDialog(context, 'Delete "${a.accountName}"? This only works if it has no transactions.');
    if (!ok || !mounted) return;
    try {
      await ApiService.instance.deleteAccount(a.id);
      if (_pager.hasClients) _pager.jumpToPage(0);
      _page = 0;
      AppNotification.show(overlay,
          title: 'Account deleted', message: '${a.accountName} was removed.', kind: NotificationKind.info);
      _load(silent: true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  double _sum(int accountId, DateTime month, bool income) {
    var total = 0.0;
    for (final t in _transactions) {
      final w = t.when;
      if (w == null || t.accountId != accountId || t.isIncome != income) continue;
      if (w.year == month.year && w.month == month.month) total += t.amount;
    }
    return total;
  }

  String _pct(double now, double before) {
    if (before == 0) return now == 0 ? '0%' : 'New';
    final p = (now - before) / before * 100;
    final sign = p >= 0 ? '+' : '';
    return '$sign${p.toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorView(error: _error!, onRetry: _load)
                : _buildContent(),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Row(
        children: [
          const Expanded(
            child: Text('My accounts', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.navy)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              backgroundColor: AppColors.blue,
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Add account'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_accounts.isEmpty) {
      return ListView(
        children: [
          _header(),
          const SizedBox(height: 40),
          EmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'No accounts yet',
            message: 'Add your MTN or Airtel wallet to start tracking. New accounts start at UGX 0; record income to add money.',
            buttonLabel: 'Add account',
            onPressed: () => _openForm(),
          ),
        ],
      );
    }

    final idx = _page >= _accounts.length ? _accounts.length - 1 : _page;
    final acc = _accounts[idx];
    final now = DateTime.now();
    final months = [for (var i = 6; i >= 0; i--) DateTime(now.year, now.month - i)];
    final previous = DateTime(_month.year, _month.month - 1);
    final income = _sum(acc.id, _month, true);
    final expense = _sum(acc.id, _month, false);
    final incomePrev = _sum(acc.id, previous, true);
    final expensePrev = _sum(acc.id, previous, false);

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _header(),
          SizedBox(
            height: 190,
            child: PageView.builder(
              controller: _pager,
              itemCount: _accounts.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => AccountCard(account: _accounts[i]),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _accounts.length; i++)
                Container(
                  margin: const EdgeInsets.all(3),
                  width: i == idx ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == idx ? AppColors.navy : AppColors.softBlue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => _openForm(acc),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.expense),
                onPressed: () => _delete(acc),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Statistics',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    const Spacer(),
                    Text('${monthShort(_month.month)} ${_month.year}',
                        style: const TextStyle(fontSize: 16, color: AppColors.blue, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    children: [
                      for (final m in months.reversed)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _month = m),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: (m.year == _month.year && m.month == _month.month)
                                    ? AppColors.navy
                                    : AppColors.paleBlue,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(monthShort(m.month),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: (m.year == _month.year && m.month == _month.month)
                                          ? Colors.white
                                          : AppColors.navyDark)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _StatTile(
                  background: AppColors.incomeSoft,
                  color: AppColors.income,
                  icon: Icons.south_west,
                  label: 'Income',
                  amount: formatUgx(income),
                  change: _pct(income, incomePrev),
                ),
                const SizedBox(height: 14),
                _StatTile(
                  background: AppColors.expenseSoft,
                  color: AppColors.expense,
                  icon: Icons.north_east,
                  label: 'Expenses',
                  amount: formatUgx(expense),
                  change: _pct(expense, expensePrev),
                ),
                const SizedBox(height: 8),
                const Text('Change is compared with the month before.',
                    style: TextStyle(fontSize: 12, color: AppColors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final Color background;
  final Color color;
  final IconData icon;
  final String label;
  final String amount;
  final String change;
  const _StatTile({
    required this.background,
    required this.color,
    required this.icon,
    required this.label,
    required this.amount,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(26)),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(amount, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Text(change, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Bottom sheet to add or edit an account. Pops with a short message when saved.
class _AccountForm extends StatefulWidget {
  final Account? existing;
  const _AccountForm({this.existing});

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.accountName);
  late final _phone = TextEditingController(text: widget.existing?.phoneNumber);
  late final _otherProvider = TextEditingController();
  String _provider = 'MTN'; // MTN, Airtel or Other
  bool _busy = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      final key = brandFor(e.provider).key;
      if (key == 'mtn') {
        _provider = 'MTN';
      } else if (key == 'airtel') {
        _provider = 'Airtel';
      } else {
        _provider = 'Other';
        _otherProvider.text = e.provider;
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _otherProvider.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final phone = _phone.text.replaceAll(RegExp(r'[\s-]'), '');
    final provider = _provider == 'Other' ? _otherProvider.text.trim() : _provider;
    try {
      if (_editing) {
        await ApiService.instance
            .updateAccount(widget.existing!.id, provider: provider, phone: phone, name: _name.text.trim());
      } else {
        await ApiService.instance.createAccount(provider: provider, phone: phone, name: _name.text.trim());
      }
      if (mounted) Navigator.pop(context, _editing ? 'Account updated' : 'Account added');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _providerChoice(String value) {
    final selected = _provider == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _provider = value),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.paleBlue : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? AppColors.blue : AppColors.border, width: selected ? 2 : 1),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 40,
                child: Center(child: ProviderLogo(provider: value == 'Other' ? 'Other' : value, size: 34)),
              ),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_editing ? 'Edit account' : 'New account',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 16),
            const Text('Provider', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.grey)),
            const SizedBox(height: 8),
            Row(children: [_providerChoice('MTN'), _providerChoice('Airtel'), _providerChoice('Other')]),
            if (_provider == 'Other') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _otherProvider,
                decoration: const InputDecoration(labelText: 'Provider name'),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter at least 2 letters' : null,
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Account name (e.g. My MTN Wallet)'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
              validator: (v) {
                final p = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
                return RegExp(r'^\+?[0-9]{9,14}$').hasMatch(p) ? null : 'Enter 9-14 digits';
              },
            ),
            if (!_editing)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('New accounts start at UGX 0. Record income to add money.',
                    style: TextStyle(fontSize: 12, color: AppColors.grey)),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: AppColors.expense)),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
