import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fmapp/src/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:fmapp/src/features/transactions/presentation/state/transaction_controller.dart';
import 'package:fmapp/src/core/presentation/widgets/loading_indicator.dart';
import 'package:fmapp/src/features/transactions/data/models/transaction.dart'; // For TransactionType
import 'package:intl/intl.dart';

class TransactionListScreen extends ConsumerWidget {
  final String? accountId; // Supabase ID of the account to filter by, if any
  final String? accountName; // For display

  const TransactionListScreen({super.key, this.accountId, this.accountName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsyncValue = ref.watch(transactionsStreamProvider(accountId));
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: 'ETB ');

    return Scaffold(
      appBar: AppBar(
        title: Text(accountName != null ? '$accountName Transactions' : 'All Transactions'),
        actions: [
           IconButton(
            icon: const Icon(Icons.sync_outlined),
            tooltip: 'Sync Transactions',
            onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Syncing transactions...')),
                );
                try {
                    await ref.read(transactionControllerProvider.notifier).syncTransactions(accountIdFilter: accountId);
                    if(context.mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Transactions synced!')),
                        );
                    }
                } catch (e) {
                    if(context.mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Sync failed: $e')),
                        );
                    }
                }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add New Transaction',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => AddTransactionScreen(initialAccountId: accountId)),
              );
            },
          ),
        ],
      ),
      body: transactionsAsyncValue.when(
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
                          MaterialPageRoute(builder: (context) => AddTransactionScreen(initialAccountId: accountId)),
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
              final isIncome = tx.transactionType == TransactionType.incomeCredit;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isIncome ? Colors.green[700] : Colors.red[700],
                    child: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward, color: Colors.white),
                  ),
                  title: Text(tx.descriptionNotes ?? tx.categoryTag ?? tx.transactionType.displayName),
                  subtitle: Text(DateFormat('MMM d, yyyy').format(tx.transactionDate)),
                  trailing: Text(
                    '${isIncome ? "+" : "-"} ${currencyFormat.format(tx.amount)}',
                    style: TextStyle(
                        color: isIncome ? Colors.green[800] : Colors.red[800],
                        fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    // TODO: Navigate to Transaction Detail / Edit Screen
                    // Navigator.of(context).push(
                    //   MaterialPageRoute(builder: (context) => AddTransactionScreen(transaction: tx)),
                    // );
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
              const Text('Error loading transactions:', style: TextStyle(fontSize: 18, color: Colors.red)),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(error.toString(), textAlign: TextAlign.center),
              ),
               const SizedBox(height: 20),
               ElevatedButton(
                 onPressed: () => ref.invalidate(transactionsStreamProvider(accountId)),
                 child: const Text("Retry")
               )
            ],
          ),
        ),
      ),
       floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => AddTransactionScreen(initialAccountId: accountId)),
          );
        },
        tooltip: 'Add Transaction',
        child: const Icon(Icons.add),
      ),
    );
  }
}
