import 'package:flutter/material.dart';

import 'typed_transactions_screen.dart';

/// Expenses tab: only money spent.
class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) => const TypedTransactionsScreen(type: 'Expense');
}
