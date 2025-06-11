import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fmapp/src/features/auth/presentation/state/auth_controller.dart';
import 'package:fmapp/src/features/financial_accounts/presentation/screens/financial_account_list_screen.dart';
import 'package:fmapp/src/features/transactions/presentation/screens/transaction_list_screen.dart';
import 'package:fmapp/src/features/friends/presentation/screens/friend_list_screen.dart'; // Import FriendListScreen
import 'package:fmapp/src/features/financial_accounts/data/models/financial_account.dart'; // For DashboardView context
import 'package:fmapp/src/features/financial_accounts/presentation/state/financial_account_controller.dart'; // For DashboardView context
import 'package:fmapp/src/features/transactions/data/models/transaction.dart'; // For DashboardView context
import 'package:fmapp/src/features/transactions/presentation/state/transaction_controller.dart'; // For DashboardView context
import 'package:fmapp/src/core/presentation/widgets/loading_indicator.dart'; // For DashboardView context
import 'package:intl/intl.dart'; // For DashboardView context


class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const DashboardView(),
    const FinancialAccountListScreen(),
    const TransactionListScreen(accountName: "All Transactions"),
    const FriendListScreen(), // Changed "Loans" placeholder to FriendListScreen
    const Text('Settings Page (Placeholder)'),
  ];

  void _onItemTapped(int index) {
    setState(() { _selectedIndex = index; });
  }

  @override
  Widget build(BuildContext context) {
    String title = "Dashboard";
    switch(_selectedIndex) {
      case 0: title = "Dashboard"; break;
      case 1: title = "My Accounts"; break;
      case 2: title = "All Transactions"; break;
      case 3: title = "Friends & Loans"; break; // Updated title for the tab
      case 4: title = "Settings"; break;
    }

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
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Accounts'),
          BottomNavigationBarItem(icon: Icon(Icons.swap_horiz_outlined), activeIcon: Icon(Icons.swap_horiz), label: 'Transactions'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined), activeIcon: Icon(Icons.people_alt), label: 'Friends & Loans'), // Updated label
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Settings'),
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

// DashboardView (Copied from previous version of dashboard_screen.dart for completeness)
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsyncValue = ref.watch(financialAccountsStreamProvider(false)); // Active accounts
    final recentTransactionsAsyncValue = ref.watch(transactionsStreamProvider(null)); // All transactions for user
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: 'ETB ');

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(financialAccountsStreamProvider(false));
        ref.invalidate(transactionsStreamProvider(null));
        try {
          await ref.read(financialAccountControllerProvider.notifier).syncFinancialAccounts();
        } catch (e) { print("Error syncing accounts on refresh: $e");}
        try {
          await ref.read(transactionControllerProvider.notifier).syncTransactions();
        } catch (e) { print("Error syncing transactions on refresh: $e");}
      },
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Financial Overview', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  accountsAsyncValue.when(
                    data: (accounts) {
                      if (accounts.isEmpty) return const Text("No active accounts to summarize.");
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text("Total Active Accounts: ${accounts.length}", style: Theme.of(context).textTheme.titleMedium),
                           const SizedBox(height: 4),
                           const Text("(Dynamic total balance display to be refined with a dedicated provider)", style: TextStyle(fontSize: 10, color: Colors.grey)),
                           const SizedBox(height: 10),
                           ...accounts.map((acc) {
                             final currentBal = acc.supabaseId != null ? ref.watch(currentBalanceProvider(acc.supabaseId!)) : acc.initialBalance;
                             return Text("${acc.accountName}: ${currencyFormat.format(currentBal)}", style: Theme.of(context).textTheme.bodyMedium);
                           }).toList(),
                        ],
                      );
                    },
                    loading: () => const LoadingIndicator(message: "Loading accounts..."),
                    error: (err, stack) => Text('Error loading accounts: $err'),
                  ),
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
                  recentTransactionsAsyncValue.when(
                    data: (transactions) {
                      if (transactions.isEmpty) return const Text("No transactions yet.");
                      final recent = transactions.take(5).toList();
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recent.length,
                        itemBuilder: (context, index) {
                          final tx = recent[index];
                          final isIncome = tx.transactionType == TransactionType.incomeCredit;
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              isIncome ? Icons.arrow_circle_up_outlined : Icons.arrow_circle_down_outlined,
                              color: isIncome ? Colors.green[700] : Colors.red[700],
                            ),
                            title: Text(tx.descriptionNotes ?? tx.categoryTag ?? tx.transactionType.displayName),
                            subtitle: Text(DateFormat('MMM d, yyyy').format(tx.transactionDate)),
                            trailing: Text(
                              '${isIncome ? "+" : "-"} ${currencyFormat.format(tx.amount)}',
                              style: TextStyle(
                                  color: isIncome ? Colors.green[800] : Colors.red[800],
                                  fontWeight: FontWeight.w500),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const LoadingIndicator(message: "Loading transactions..."),
                    error: (err, stack) => Text('Error loading transactions: $err'),
                  ),
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
                  const Text('Total Lent: ETB ---.--'),
                  const Text('Total Owed: ETB ---.--'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
