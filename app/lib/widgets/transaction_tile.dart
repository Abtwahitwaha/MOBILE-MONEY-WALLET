import 'package:flutter/material.dart';

import '../models/wallet_transaction.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';

/// One row of a transaction list. Income and expenses look clearly different:
/// green strip, down-left arrow and "INCOME" for money in; red strip, up-right arrow and "EXPENSE" for money out.
class TransactionTile extends StatelessWidget {
  final WalletTransaction t;
  final VoidCallback onTap;
  const TransactionTile({super.key, required this.t, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = t.isIncome ? AppColors.income : AppColors.expense;
    final soft = t.isIncome ? AppColors.incomeSoft : AppColors.expenseSoft;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 6, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
                          child: Icon(t.isIncome ? Icons.south_west : Icons.north_east, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.ink)),
                              const SizedBox(height: 2),
                              Text('${t.categoryName} - ${t.accountName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: AppColors.grey)),
                              Text(formatDateTime(t.when), style: const TextStyle(fontSize: 11, color: AppColors.grey)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${t.sign}${formatUgx(t.amount, prefix: false)}',
                                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(10)),
                              child: Text(t.isIncome ? 'INCOME' : 'EXPENSE',
                                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
