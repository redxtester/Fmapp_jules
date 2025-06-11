import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fmapp/src/features/transactions/data/models/transaction.dart';
import 'package:fmapp/src/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:fmapp/src/features/transactions/presentation/state/transaction_controller.dart';
import 'package:fmapp/src/features/financial_accounts/data/models/financial_account.dart'; // For account names
import 'package:fmapp/src/features/financial_accounts/presentation/state/financial_account_controller.dart'; // To get account names
import 'package:fmapp/src/core/presentation/widgets/loading_indicator.dart';
import 'package:intl/intl.dart';

class TransactionListScreen extends ConsumerWidget {
  final String? accountId; // Supabase ID of the account to filter by (this is the account being viewed)
  final String? accountName; // For display

  const TransactionListScreen({super.key, this.accountId, this.accountName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Stream of transactions for the current account context (this.accountId)
    // The repository's watchTransactionsLocal was updated to fetch where accountId is either affected or counterparty
    final transactionsAsyncValue = ref.watch(transactionsStreamProvider(this.accountId));
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: 'ETB ');

    // We need to fetch all accounts to display names for counterparty/source in transfers
    // This is not ideal to fetch all accounts just for names, but for P0 it's simpler.
    // A better solution might be a provider that resolves account names by ID on demand.
    final allAccountsAsync = ref.watch(financialAccountsStreamProvider(true)); // Include archived for name lookup

    return Scaffold(
      appBar: AppBar(
        title: Text(this.accountName != null ? '${this.accountName} Transactions' : 'All Transactions'),
        actions: [
           IconButton(
            icon: const Icon(Icons.sync_outlined),
            tooltip: 'Sync Transactions',
            onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Syncing transactions...')));
                try {
                    await ref.read(transactionControllerProvider.notifier).syncTransactions(accountIdFilter: this.accountId);
                    if(context.mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transactions synced!')));
                    }
                } catch (e) { if(context.mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
                }}
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add New Transaction',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => AddTransactionScreen(initialAccountId: this.accountId)),
              );
            },
          ),
        ],
      ),
      body: allAccountsAsync.when(
        data: (allAccountsList) {
          final accountNameMap = {for (var acc in allAccountsList) acc.supabaseId: acc.accountName};

          return transactionsAsyncValue.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No transactions found.', style: TextStyle(fontSize: 18)),
                       const SizedBox(height: 8),
                      const Text('Tap the "+" icon to add your first transaction.', textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                       ElevatedButton.icon(
                         icon: const Icon(Icons.add),
                         label: const Text("Add Transaction"),
                         onPressed: (){
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => AddTransactionScreen(initialAccountId: this.accountId)),
                            );
                         }
                       )
                    ],
                  ),
                );
              }
              return ListView.builder(
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  String title;
                  String subtitle = DateFormat('MMM d, yyyy').format(tx.transactionDate);
                  IconData leadingIconData;
                  Color leadingIconColor;
                  String amountString;
                  bool isNeutralFlowForThisAccount = false;

                  if (tx.isInternalTransfer) {
                    leadingIconData = Icons.compare_arrows_outlined;
                    leadingIconColor = Colors.blueGrey;
                    final sourceAccountName = accountNameMap[tx.affectedAccountId] ?? 'Unknown Account';
                    final destAccountName = accountNameMap[tx.counterpartyAccountId] ?? 'Unknown Account';

                    if (this.accountId == tx.affectedAccountId) {
                      title = 'Transfer to $destAccountName';
                      amountString = '- ${currencyFormat.format(tx.amount)}';
                      leadingIconColor = Colors.orange[700]!;
                    } else if (this.accountId == tx.counterpartyAccountId) {
                      title = 'Transfer from $sourceAccountName';
                      amountString = '+ ${currencyFormat.format(tx.amount)}';
                      leadingIconColor = Colors.teal[700]!;
                    } else {
                      title = 'Transfer: $sourceAccountName to $destAccountName';
                      amountString = currencyFormat.format(tx.amount);
                      isNeutralFlowForThisAccount = true;
                    }
                    subtitle += ' (${tx.descriptionNotes ?? "Internal Transfer"})';
                  } else {
                    final isIncome = tx.transactionType == TransactionType.incomeCredit;
                    leadingIconData = isIncome ? Icons.arrow_circle_up_outlined : Icons.arrow_circle_down_outlined;
                    leadingIconColor = isIncome ? Colors.green[700]! : Colors.red[700]!;
                    title = tx.descriptionNotes ?? tx.categoryTag ?? tx.transactionType.displayName;
                    amountString = '${isIncome ? "+" : "-"} ${currencyFormat.format(tx.amount)}';
                    if (tx.categoryTag != null && (tx.descriptionNotes != null && tx.descriptionNotes != tx.categoryTag)) {
                        subtitle += ' (${tx.categoryTag})';
                    }
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: leadingIconColor,
                        child: Icon(leadingIconData, color: Colors.white, size: 20),
                      ),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
                      trailing: Text(
                        amountString,
                        style: TextStyle(
                            color: isNeutralFlowForThisAccount
                                   ? Colors.blueGrey
                                   : (amountString.startsWith('+') ? Colors.green[800] : Colors.red[800]),
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      onTap: () {
                        // TODO: Navigate to Transaction Detail / Edit Screen
                        // For P0, edit is not implemented in AddTransactionScreen for tx.
                        // if (tx.supabaseId != null) {
                        //   Navigator.of(context).push(
                        //     MaterialPageRoute(builder: (context) => AddTransactionScreen(transactionToEdit: tx)),
                        //   );
                        // }
                      },
                    ),
                  );
                },
              );
            },
            loading: () => const LoadingIndicator(message: 'Loading transactions...'),
            error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 60),
                    const SizedBox(height: 16),
                    const Text('Error loading transactions.', style: TextStyle(fontSize: 18, color: Colors.red)),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(error.toString(), textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(transactionsStreamProvider(this.accountId)),
                      child: const Text("Retry")
                    )
                  ],
                ),
            ),
          );
        },
        loading: () => const LoadingIndicator(message: 'Loading account data...'),
        error: (error, stack) => Center(child: Text("Error loading account names for display: $error")),
      ),
       floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => AddTransactionScreen(initialAccountId: this.accountId)),
          );
        },
        tooltip: 'Add Transaction',
        child: const Icon(Icons.add),
      ),
    );
  }
}
