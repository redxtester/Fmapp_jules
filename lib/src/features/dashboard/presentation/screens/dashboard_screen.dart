import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fmapp/src/features/auth/presentation/state/auth_controller.dart';
// import 'package:fmapp/src/features/sim_cards/presentation/screens/sim_card_list_screen.dart'; // Keep if SIMs is a separate tab
import 'package:fmapp/src/features/financial_accounts/presentation/screens/financial_account_list_screen.dart'; // Import Account List Screen

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0; // Default to Dashboard tab

  // Updated widget options
  static final List<Widget> _widgetOptions = <Widget>[
    const DashboardView(),
    const FinancialAccountListScreen(), // Tab 1 is now Accounts
    // TODO: Add SimCardListScreen as its own tab or integrate elsewhere if needed
    const Text('Transactions Page (Placeholder)'), // Tab 2
    const Text('Loans Page (Placeholder)'), // Tab 3
    const Text('Settings Page (Placeholder)'), // Tab 4
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    String title = "fmapp Dashboard";
    if (_selectedIndex == 1) title = "My Accounts";
    if (_selectedIndex == 2) title = "Transactions";
    if (_selectedIndex == 3) title = "Loans";
    if (_selectedIndex == 4) title = "Settings";
    // Add other titles as other tabs are implemented

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
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
            icon: Icon(Icons.people_alt_outlined),
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
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey[600],
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }
}

// DashboardView remains the same for now
class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          'Welcome to fmapp!',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Financial Overview (Placeholder)', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Total Balance: ETB X,XXX.XX'),
                const Text('Cash: ETB Y,YYY.YY'),
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
                Text('Recent Transactions (Placeholder)', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const ListTile(leading: Icon(Icons.arrow_downward, color: Colors.red), title: Text('Groceries'), trailing: Text('- ETB 500.00')),
                const ListTile(leading: Icon(Icons.arrow_upward, color: Colors.green), title: Text('Freelance Payment'), trailing: Text('+ ETB 2,500.00')),
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
                Text('Loan Summary (Placeholder)', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Total Lent: ETB ZZZ.ZZ'),
                const Text('Total Owed: ETB WWW.WW'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
