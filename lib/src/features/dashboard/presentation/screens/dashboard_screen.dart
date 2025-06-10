import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fmapp/src/features/auth/presentation/state/auth_controller.dart'; // For logout

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0; // For BottomNavigationBar

  // Placeholder pages for other main sections
  static const List<Widget> _widgetOptions = <Widget>[
    DashboardView(), // Actual dashboard content
    Text('Accounts Page (Placeholder)'),
    Text('Transactions Page (Placeholder)'),
    Text('Loans Page (Placeholder)'),
    Text('Settings Page (Placeholder)'),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // TODO: Implement actual navigation or page view update for other tabs
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('fmapp Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              // AuthGate will handle navigation to LoginScreen
            },
          )
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Accounts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz_outlined),
            activeIcon: Icon(Icons.swap_horiz),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined), // Or specific loan icon
            activeIcon: Icon(Icons.people_alt),
            label: 'Loans',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor, // Use theme color
        unselectedItemColor: Colors.grey[600],
        showUnselectedLabels: true, // Good for discoverability
        type: BottomNavigationBarType.fixed, // Fixed when more than 3 items
        onTap: _onItemTapped,
      ),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    // This will be built out further in subsequent steps
    // For now, a simple placeholder message.
    // PRD 4.6.1: total balance per SIM, recent transactions, outstanding loans/debts
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          'Welcome to fmapp!',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        // Placeholder cards for dashboard items
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SIM Balances Summary', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('SIM 1 (Ethio): ETB 1,234.56'),
                const Text('SIM 2 (Safaricom): ETB 789.00'),
                // Data will come from providers later
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recent Transactions', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const ListTile(leading: Icon(Icons.arrow_downward, color: Colors.red), title: Text('Netflix Subscription'), trailing: Text('- ETB 350.00')),
                const ListTile(leading: Icon(Icons.arrow_upward, color: Colors.green), title: Text('Salary Deposit'), trailing: Text('+ ETB 15,000.00')),
                // Data will come from providers later
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
         Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Loan Summary', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Total Lent: ETB 500.00'),
                const Text('Total Owed: ETB 250.00'),
                // Data will come from providers later
              ],
            ),
          ),
        ),
      ],
    );
  }
}
