import 'package:fmapp/src/features/financial_accounts/data/models/financial_account.dart';
import 'package:fmapp/src/features/financial_accounts/presentation/screens/add_edit_financial_account_screen.dart';
import 'package:fmapp/src/features/financial_accounts/presentation/state/financial_account_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fmapp/src/core/presentation/widgets/loading_indicator.dart';
import 'package:intl/intl.dart'; // For currency formatting

// Provider to control the filter for showing archived accounts
final showArchivedAccountsProvider = StateProvider<bool>((ref) => false);

class FinancialAccountListScreen extends ConsumerWidget {
  const FinancialAccountListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool includeArchived = ref.watch(showArchivedAccountsProvider);
    // Use the stream provider with the family parameter
    final accountsAsyncValue = ref.watch(financialAccountsStreamProvider(includeArchived));
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: 'ETB '); // Basic ETB format

    return Scaffold(
      // AppBar will be part of DashboardScreen usually, but can have one here if this screen is pushed standalone
      // For tab view, AppBar is typically managed by the parent (DashboardScreen)
      // For now, let's assume it might be pushed, so it has its own app bar.
      // If it's always a tab, this AppBar might be redundant or handled differently.
      appBar: AppBar(
        title: Text(includeArchived ? 'All Accounts' : 'Active Accounts'),
        actions: [
          IconButton(
            icon: Icon(includeArchived ? Icons.inventory_2_outlined : Icons.inventory_2),
            onPressed: () => ref.read(showArchivedAccountsProvider.notifier).update((state) => !state),
            tooltip: includeArchived ? 'Hide Archived' : 'Show Archived',
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing accounts...')),
              );
              try {
                await ref.read(financialAccountControllerProvider.notifier).syncFinancialAccounts();
                if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Accounts synced successfully!')),
                    );
                }
              } catch (e) {
                 if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error syncing accounts: $e')),
                    );
                 }
              }
            },
            tooltip: 'Sync with Cloud',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddEditFinancialAccountScreen()),
              );
            },
            tooltip: 'Add New Account',
          ),
        ],
      ),
      body: accountsAsyncValue.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(includeArchived ? 'No accounts found.' : 'No active accounts found.', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text('Tap the "+" icon to add your first financial account.', textAlign: TextAlign.center),
                   const SizedBox(height: 20),
                   ElevatedButton.icon(
                     icon: const Icon(Icons.add),
                     label: const Text("Add Account"),
                     onPressed: (){
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const AddEditFinancialAccountScreen()),
                        );
                     }
                   )
                ],
              ),
            );
          }
          // Group accounts by type for better display (optional)
          // Map<AccountType, List<FinancialAccount>> groupedAccounts = {};
          // for (var acc in accounts) {
          //   (groupedAccounts[acc.accountType] ??= []).add(acc);
          // }

          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              // TODO: Implement currentBalance calculation later when transactions exist
              final currentBalanceDisplay = account.initialBalance; // Placeholder

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: account.isArchived ? Colors.grey[300] : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getAccountTypeColor(account.accountType, context),
                    child: Icon(_getAccountTypeIcon(account.accountType), color: Colors.white),
                  ),
                  title: Text(account.accountName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${account.accountIdentifier ?? account.accountType.name}\nInitial: ${currencyFormat.format(account.initialBalance)} \nCurrent: ${currencyFormat.format(currentBalanceDisplay)}'
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => AddEditFinancialAccountScreen(account: account)),
                        );
                      } else if (value == 'archive_restore') {
                         try {
                            await ref.read(financialAccountControllerProvider.notifier).toggleArchiveFinancialAccount(account);
                            if(context.mounted){
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Account "${account.accountName}" ${account.isArchived ? "restored" : "archived"}.')),
                                );
                            }
                         } catch(e){
                             if(context.mounted){
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                            }
                         }
                      } else if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Confirm Delete'),
                            content: Text('Are you sure you want to delete account "${account.accountName}"? This may affect associated transactions (not yet implemented).'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && account.supabaseId != null) {
                           try {
                            await ref.read(financialAccountControllerProvider.notifier).deleteFinancialAccount(account.supabaseId!, account.isarId);
                            if(context.mounted){
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Account "${account.accountName}" deleted.')),
                                );
                            }
                           } catch(e){
                               if(context.mounted){
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error deleting account: $e')),
                                );
                               }
                           }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: 'archive_restore',
                        child: Text(account.isArchived ? 'Restore' : 'Archive')
                      ),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const LoadingIndicator(message: 'Loading accounts...'),
        error: (error, stack) => Center(
           child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              const Text('Error loading accounts:', style: TextStyle(fontSize: 18, color: Colors.red)),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(error.toString(), textAlign: TextAlign.center),
              ),
               const SizedBox(height: 20),
               ElevatedButton(
                 onPressed: () => ref.invalidate(financialAccountsStreamProvider(includeArchived)),
                 child: const Text("Retry")
               )
            ],
          ),
        ),
      ),
    );
  }

  IconData _getAccountTypeIcon(AccountType type) {
    switch (type) {
      case AccountType.bankAccount: return Icons.account_balance;
      case AccountType.mobileWallet: return Icons.phone_android;
      case AccountType.onlineMoney: return Icons.public;
      case AccountType.cash: return Icons.money;
      default: return Icons.credit_card;
    }
  }
  Color _getAccountTypeColor(AccountType type, BuildContext context) {
    switch (type) {
      case AccountType.bankAccount: return Colors.blue[700]!;
      case AccountType.mobileWallet: return Colors.green[700]!;
      case AccountType.onlineMoney: return Colors.purple[700]!;
      case AccountType.cash: return Colors.orange[700]!;
      default: return Theme.of(context).primaryColor;
    }
  }
}
