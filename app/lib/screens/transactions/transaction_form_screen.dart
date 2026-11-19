import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/wallet_category.dart';
import '../../models/wallet_transaction.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/category_rules.dart';
import '../../utils/format.dart';
import '../../widgets/app_notification.dart';
import '../../widgets/error_view.dart';
import '../../widgets/pin_sheet.dart';
import '../../widgets/provider_logo.dart';
import '../../widgets/square_button.dart';

/// Separate screen for recording money received.
class AddIncomeScreen extends StatelessWidget {
  const AddIncomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const TransactionFormScreen(type: 'Income');
}

/// Separate screen for recording money spent (asks for the security PIN before saving).
class AddExpenseScreen extends StatelessWidget {
  const AddExpenseScreen({super.key});

  @override
  Widget build(BuildContext context) => const TransactionFormScreen(type: 'Expense');
}

/// The shared form behind Add Income, Add Expense and Edit. The type is fixed per screen.
class TransactionFormScreen extends StatefulWidget {
  final String type; // "Income" or "Expense"
  final WalletTransaction? existing;
  const TransactionFormScreen({super.key, required this.type, this.existing});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  static const _quickAmounts = [5000, 10000, 20000, 50000];

  final _amount = TextEditingController();
  final _description = TextEditingController();

  List<Account> _accounts = [];
  List<WalletCategory> _categories = [];
  int? _accountId;
  int? _categoryId;

  bool _loading = true;
  bool _saving = false;
  Object? _loadError;
  String? _formError;

  bool get _isIncome => widget.type == 'Income';
  bool get _editing => widget.existing != null;
  Color get _color => _isIncome ? AppColors.income : AppColors.expense;
  Color get _soft => _isIncome ? AppColors.incomeSoft : AppColors.expenseSoft;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _accountId = e.accountId;
      _categoryId = e.categoryId;
      _amount.text = e.amount == e.amount.roundToDouble() ? e.amount.toStringAsFixed(0) : e.amount.toString();
      _description.text = e.description ?? '';
    }
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  // Accounts and categories come from the backend (an "Other" category is created if missing).
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = ApiService.instance;
      final accounts = await api.getAccounts();
      final categories = await api.getCategories(ensureOther: true);
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _categories = categories;
        if (_accountId == null && accounts.length == 1) _accountId = accounts.first.id;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e;
          _loading = false;
        });
      }
    }
  }

  double? _parseAmount() => double.tryParse(_amount.text.replaceAll(',', '').trim());

  void _setAmount(num value) {
    setState(() {
      _amount.text = value.toStringAsFixed(0);
      _formError = null;
    });
  }

  void _bump(int delta) {
    final current = _parseAmount() ?? 0;
    final next = current + delta;
    _setAmount(next < 0 ? 0 : next);
  }

  Account? _findAccount() {
    for (final a in _accounts) {
      if (a.id == _accountId) return a;
    }
    return null;
  }

  WalletCategory? _findCategory() {
    for (final c in _categories) {
      if (c.id == _categoryId) return c;
    }
    return null;
  }

  Future<void> _save() async {
    final overlay = Overlay.of(context, rootOverlay: true); // for the pop-up notification later
    final amount = _parseAmount();
    final acc = _findAccount();
    final cat = _findCategory();
    final noun = _isIncome ? 'income' : 'expense';

    String? error;
    if (acc == null) {
      error = 'Choose an account.';
    } else if (amount == null || amount <= 0) {
      error = 'Enter an amount greater than 0.';
    } else if (cat == null) {
      error = 'Choose a category.';
    } else if (isOtherCategory(cat.name) && _description.text.trim().isEmpty) {
      error = 'Please describe this $noun (required for "Other").';
    } else if (!_isIncome && !_editing && amount > acc.balance) {
      error = 'Not enough money in ${acc.accountName} (balance ${formatUgx(acc.balance)}).';
    }
    if (error != null) {
      setState(() => _formError = error);
      return;
    }

    // Security: every expense must be approved with the local PIN.
    if (!_isIncome) {
      final approved = await showPinSheet(
        context,
        purpose: PinPurpose.confirmExpense,
        summaryTitle: formatUgx(amount!),
        summaryLine: 'From ${acc!.accountName} - ${cat!.name}',
      );
      if (!approved || !mounted) return;
    }

    setState(() {
      _formError = null;
      _saving = true;
    });
    final desc = _description.text.trim().isEmpty ? null : _description.text.trim();
    try {
      final api = ApiService.instance;
      if (_editing) {
        await api.updateTransaction(widget.existing!.id,
            accountId: _accountId!, categoryId: _categoryId!, type: widget.type, amount: amount!, description: desc);
      } else {
        await api.createTransaction(
            accountId: _accountId!, categoryId: _categoryId!, type: widget.type, amount: amount!, description: desc);
      }
      String? balance;
      try {
        balance = formatUgx((await api.getAccount(_accountId!)).balance);
      } catch (_) {}
      final sign = _isIncome ? '+' : '-';
      AppNotification.show(
        overlay,
        title: _editing ? '${_isIncome ? 'Income' : 'Expense'} updated' : '${_isIncome ? 'Income' : 'Expense'} recorded',
        message: '$sign${formatUgx(amount!)} - ${acc!.accountName}${balance == null ? '' : '\nNew balance: $balance'}',
        kind: _isIncome ? NotificationKind.income : NotificationKind.expense,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e); // e.g. "Insufficient balance in ..."
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? ErrorView(error: _loadError!, onRetry: _load)
                : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    final title = _editing ? (_isIncome ? 'Edit income' : 'Edit expense') : (_isIncome ? 'Add income' : 'Add expense');
    final categories = categoriesForType(widget.type, _categories, keepId: widget.existing?.categoryId);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Row(
          children: [
            SquareIconButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
            Expanded(
              child: Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.navy)),
            ),
            const SizedBox(width: 52),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
                child: Icon(_isIncome ? Icons.south_west : Icons.north_east, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isIncome ? 'Money coming IN to your account' : 'Money going OUT of your account',
                  style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _label('Choose account'),
        if (_accounts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('You have no accounts yet. Go to the Accounts tab and add one first.',
                style: TextStyle(color: AppColors.expense)),
          )
        else
          for (final a in _accounts) _accountOption(a),
        const SizedBox(height: 10),
        _label('How much?'),
        Row(
          children: [
            _stepButton(Icons.remove, AppColors.softBlue, AppColors.navy, () => _bump(-1000)),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _color),
                decoration: const InputDecoration(
                  prefixText: 'UGX ',
                  hintText: '0',
                  contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                ),
                onChanged: (_) => setState(() => _formError = null),
              ),
            ),
            const SizedBox(width: 10),
            _stepButton(Icons.add, AppColors.blue, Colors.white, () => _bump(1000)),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [for (final v in _quickAmounts) _quickChip(v)],
        ),
        const SizedBox(height: 24),
        _label('Choose category'),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [for (final c in categories) _categoryTile(c)],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _description,
          maxLength: 255,
          decoration: InputDecoration(
            labelText: (_findCategory() != null && isOtherCategory(_findCategory()!.name))
                ? 'Describe it (required for "Other")'
                : 'Description (optional)',
          ),
          onChanged: (_) => setState(() => _formError = null),
        ),
        if (!_isIncome)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: AppColors.grey),
                SizedBox(width: 6),
                Expanded(
                  child: Text('You will be asked for your security PIN to approve this expense.',
                      style: TextStyle(fontSize: 12, color: AppColors.grey)),
                ),
              ],
            ),
          ),
        if (_formError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_formError!, style: const TextStyle(color: AppColors.expense, fontSize: 15)),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.softBlue,
                  foregroundColor: AppColors.navy,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _color,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_editing ? 'Save changes' : (_isIncome ? 'Save income' : 'Save expense')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.navy)),
      );

  Widget _accountOption(Account a) {
    final selected = a.id == _accountId;
    return GestureDetector(
      onTap: () => setState(() {
        _accountId = a.id;
        _formError = null;
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? AppColors.blue : AppColors.border, width: selected ? 2 : 1),
          boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            SizedBox(width: 56, child: Center(child: ProviderLogo(provider: a.provider, size: 34))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.accountName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.ink)),
                  Text('${a.provider} - ${maskPhone(a.phoneNumber)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.grey)),
                  Text('Balance ${formatUgx(a.balance)}', style: const TextStyle(fontSize: 12, color: AppColors.blue)),
                ],
              ),
            ),
            Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.grey)),
              child: selected
                  ? Center(
                      child: Container(
                        width: 17,
                        height: 17,
                        decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepButton(IconData icon, Color bg, Color fg, VoidCallback onTap) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(width: 56, height: 52, child: Icon(icon, color: fg)),
      ),
    );
  }

  Widget _quickChip(int value) {
    return GestureDetector(
      onTap: () => _setAmount(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.softBlue, width: 2),
        ),
        child: Text('UGX ${formatUgx(value.toDouble(), prefix: false)}',
            style: const TextStyle(fontSize: 14, color: AppColors.navy)),
      ),
    );
  }

  Widget _categoryTile(WalletCategory c) {
    final selected = c.id == _categoryId;
    return GestureDetector(
      onTap: () => setState(() {
        _categoryId = c.id;
        _formError = null;
      }),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              width: 66,
              height: 59,
              decoration: BoxDecoration(
                color: selected ? _color : AppColors.paleBlue,
                borderRadius: BorderRadius.circular(18),
                border: selected ? Border.all(color: AppColors.navy, width: 2) : null,
              ),
              child: Icon(categoryIcon(c.icon), color: selected ? Colors.white : AppColors.navy),
            ),
            const SizedBox(height: 4),
            Text(c.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
