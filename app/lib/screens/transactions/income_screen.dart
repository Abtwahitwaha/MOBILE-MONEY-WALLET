import 'package:flutter/material.dart';

import 'typed_transactions_screen.dart';

/// Income tab: only money received.
class IncomeScreen extends StatelessWidget {
  const IncomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const TypedTransactionsScreen(type: 'Income');
}
