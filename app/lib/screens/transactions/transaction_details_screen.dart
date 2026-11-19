import 'package:flutter/material.dart';

import '../../models/wallet_transaction.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/format.dart';
import '../../widgets/app_notification.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/error_view.dart';
import '../../widgets/square_button.dart';
import 'transaction_form_screen.dart';

/// Details of one transaction, with Edit and Delete.
class TransactionDetailsScreen extends StatefulWidget {
  final WalletTransaction transaction;
  const TransactionDetailsScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailsScreen> createState() => _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends State<TransactionDetailsScreen> {
  bool _busy = false;

  WalletTransaction get t => widget.transaction;

  Future<void> _edit() async {
    final changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => TransactionFormScreen(type: t.type, existing: t)));
    if (changed == true && mounted) Navigator.pop(context, true); // list screens reload
  }

  Future<void> _delete() async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final ok = await confirmDialog(context, 'Delete this transaction? The account balance will be corrected.');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ApiService.instance.deleteTransaction(t.id);
      String? balance;
      try {
        balance = formatUgx((await ApiService.instance.getAccount(t.accountId)).balance);
      } catch (_) {}
      AppNotification.show(
        overlay,
        title: '${t.isIncome ? 'Income' : 'Expense'} deleted',
        message: '${t.sign}${formatUgx(t.amount)} removed from ${t.accountName}'
            '${balance == null ? '' : '\nNew balance: $balance'}',
        kind: NotificationKind.info,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e); // e.g. deleting income that was already spent
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = t.isIncome ? AppColors.income : AppColors.expense;
    final soft = t.isIncome ? AppColors.incomeSoft : AppColors.expenseSoft;
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      SquareIconButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                      const Expanded(
                        child: Text('Transaction details',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.snow, fontSize: 22, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 52),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.isIncome ? Icons.south_west : Icons.north_east, color: color, size: 18),
                        const SizedBox(width: 6),
                        Text(t.isIncome ? 'INCOME' : 'EXPENSE',
                            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('${t.sign}${formatUgx(t.amount)}',
                        style: const TextStyle(color: AppColors.snow, fontSize: 36, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 6),
                  Text(t.title, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate, fontSize: 16)),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
                ),
                child: ListView(
                  children: [
                    _row('Category', t.categoryName),
                    _row('Account', t.accountName),
                    _row('Date', formatDateTime(t.when)),
                    if (t.description != null && t.description!.trim().isNotEmpty) _row('Description', t.description!),
                    _row('Reference', 'TXN-${t.id.toString().padLeft(6, '0')}'),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _busy ? null : _edit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        foregroundColor: AppColors.expense,
                        side: const BorderSide(color: AppColors.expense),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _busy ? null : _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 15))),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(color: AppColors.ink, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
