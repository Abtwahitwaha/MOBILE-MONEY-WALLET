import 'package:flutter/material.dart';

import '../models/wallet_transaction.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'app_notification.dart';
import 'dialogs.dart';
import 'error_view.dart';

/// Swipe a transaction to the LEFT to delete it. The user is asked to confirm,
/// the backend deletes it (and corrects the balance), then [onDeleted] removes it from the list.
class SwipeToDelete extends StatelessWidget {
  final WalletTransaction transaction;
  final Widget child;
  final VoidCallback onDeleted;

  const SwipeToDelete({super.key, required this.transaction, required this.child, required this.onDeleted});

  Future<bool> _confirmAndDelete(BuildContext context) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final t = transaction;
    final ok = await confirmDialog(
      context,
      'Delete "${t.title}" (${t.sign}${formatUgx(t.amount)})? The account balance will be corrected.',
    );
    if (!ok) return false;
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
      return true;
    } catch (e) {
      if (context.mounted) showError(context, e); // e.g. deleting income that was already spent
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('tx-${transaction.id}'),
      direction: DismissDirection.endToStart, // swipe left
      confirmDismiss: (_) => _confirmAndDelete(context),
      onDismissed: (_) => onDeleted(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: AppColors.expense, borderRadius: BorderRadius.circular(20)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Colors.white),
          ],
        ),
      ),
      child: child,
    );
  }
}
