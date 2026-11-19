import 'package:flutter/material.dart';

import 'accounts/accounts_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'transactions/expenses_screen.dart';
import 'transactions/income_screen.dart';

/// The app frame: five clearly labelled tabs along the bottom.
/// A tab is rebuilt each time it is opened, so it always shows fresh data from the server.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  Widget _page() {
    switch (_index) {
      case 1:
        return const IncomeScreen();
      case 2:
        return const ExpensesScreen();
      case 3:
        return const AccountsScreen();
      case 4:
        return const ProfileScreen();
      default:
        return HomeScreen(onNavigate: _go);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _page(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.arrow_circle_down_outlined),
              selectedIcon: Icon(Icons.arrow_circle_down),
              label: 'Income'),
          NavigationDestination(
              icon: Icon(Icons.arrow_circle_up_outlined),
              selectedIcon: Icon(Icons.arrow_circle_up),
              label: 'Expenses'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Accounts'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
