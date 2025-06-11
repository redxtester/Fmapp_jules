import 'package:fmapp/src/features/financial_accounts/data/models/financial_account.dart';
import 'package:fmapp/src/features/financial_accounts/presentation/screens/add_edit_financial_account_screen.dart';
import 'package:fmapp/src/features/financial_accounts/presentation/state/financial_account_controller.dart';
import 'package:fmapp/src/features/transactions/presentation/screens/transaction_list_screen.dart';
import 'package:fmapp/src/features/transactions/presentation/state/transaction_controller.dart'; // For currentBalanceProvider
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fmapp/src/core/presentation/widgets/loading_indicator.dart';
import 'package:intl/intl.dart';

final showArchivedAccountsProvider = StateProvider<bool>((ref) => false);

class FinancialAccountListScreen extends ConsumerWidget {
  const FinancialAccountListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool includeArchived = ref.watch(showArchivedAccountsProvider);
    final accountsAsyncValue = ref.watch(financialAccountsStreamProvider(includeArchived));
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: 'ETB ');

    return Scaffold(
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Syncing accounts...')));
              try {
                await ref.read(financialAccountControllerProvider.notifier).syncFinancialAccounts();
                if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accounts synced!')));
                }
              } catch (e) { if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync error: $e')));
              }}
            },
            tooltip: 'Sync with Cloud',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AddEditFinancialAccountScreen())),
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
                  const Icon(Icons.account_balance_wallet_outlined, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(includeArchived ? 'No accounts found.' : 'No active accounts found.', style: const TextStyle(fontSize: 18)),
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
          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              // Watch the current balance for this specific account
              final currentBalance = account.supabaseId != null
                  ? ref.watch(currentBalanceProvider(account.supabaseId!))
                  : account.initialBalance; // Fallback if no supabaseId (should not happen for synced accounts)

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
                    '${account.accountIdentifier ?? account.accountType.name}\nInitial: ${currencyFormat.format(account.initialBalance)}\nCurrent: ${currencyFormat.format(currentBalance)}'
                  ),
                  isThreeLine: true,
                  onTap: () {
                    if (account.supabaseId != null) {
                      Navigator.of(context).push(MaterialPageRoute(builder: (context) => TransactionListScreen(
                        accountId: account.supabaseId!,
                        accountName: account.accountName,
                      )));
                    } else {
                       ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cannot view transactions: Account not synced.')),
                      );
                    }
                  },
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
                      } else if (value == 'delete' && account.supabaseId != null) {
                           try {
                            await ref.read(financialAccountControllerProvider.notifier).deleteFinancialAccount(account.supabaseId!, account.isarId);
                            // No need to invalidate currentBalanceProvider here for the deleted account.
                            // The account will disappear from the list.
                           } catch(e){
                               String errorMessage = 'Error deleting account: $e';
                               if (e.toString().contains('violates foreign key constraint') && e.toString().contains("transactions_affected_account_id_fkey")) {
                                   errorMessage = 'Cannot delete: Account has transactions.';
                               }
                               if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
                           }
                        }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'archive_restore', child: Text(account.isArchived ? 'Restore' : 'Archive')),
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
      case AccountType.bankAccount: return Colors.blue[600]!;
      case AccountType.mobileWallet: return Colors.green[600]!;
      case AccountType.onlineMoney: return Colors.purple[600]!;
      case AccountType.cash: return Colors.orange[600]!;
      default: return Theme.of(context).primaryColorDark;
    }
  }
}
