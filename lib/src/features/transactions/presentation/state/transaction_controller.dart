import 'dart:async';
import 'package:fmapp/src/features/transactions/data/models/transaction.dart';
import 'package:fmapp/src/features/transactions/data/repositories/transaction_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart'; // For Id type

// Provider for TransactionController
// Manages a list of transactions, perhaps for a specific account or recent transactions.
// For a general list, it might become very large.
// Consider if this controller should manage *all* transactions or be more specific.
// For now, let's assume it's for general transaction operations and can fetch/refresh.
final transactionControllerProvider =
    AsyncNotifierProvider<TransactionController, List<Transaction>>(() {
  return TransactionController();
});

// Stream provider for transactions, family by accountId (nullable for all user's transactions)
// This is likely more useful for displaying lists of transactions.
final transactionsStreamProvider =
    StreamProvider.autoDispose.family<List<Transaction>, String?>((ref, accountId) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.watchTransactionsLocal(accountId);
});

// Provider to calculate current balance for a specific account
// This will recompute when transactions for that account change or when the account's initial balance changes.
// It needs access to the FinancialAccount's initialBalance and its transactions.
// This is a conceptual placement; it might live elsewhere or be part of FinancialAccountController.
final currentBalanceProvider = Provider.autoDispose.family<double, String>((ref, accountSupabaseId) {
  final transactions = ref.watch(transactionsStreamProvider(accountSupabaseId)).value ?? [];
  // We need the financial account's initial balance.
  // This requires access to FinancialAccount data. This provider might need to be more complex
  // or this logic lives within FinancialAccount's domain.
  // For now, placeholder:
  final initialBalance = 0.0; // Placeholder - This needs to be fetched for the account.

  double currentBalance = initialBalance;
  for (var tx in transactions) {
    if (tx.transactionType == TransactionType.incomeCredit) {
      currentBalance += tx.amount;
    } else if (tx.transactionType == TransactionType.expenseDebit) {
      currentBalance -= tx.amount;
    }
  }
  return currentBalance;
});


class TransactionController extends AsyncNotifier<List<Transaction>> {
  late TransactionRepository _repository;
  String? _currentAccountIdFilter; // Optional filter for the list this controller manages

  @override
  Future<List<Transaction>> build() async {
    _repository = ref.watch(transactionRepositoryProvider);
    // Load initial transactions, possibly filtered if _currentAccountIdFilter is set
    return _repository.getTransactionsLocal(accountIdFilter: _currentAccountIdFilter);
  }

  void setAccountIdFilter(String? accountId) {
    _currentAccountIdFilter = accountId;
    _refreshState(); // Refresh the list with the new filter
  }

  Future<void> addTransaction(Transaction transaction) async {
    // Set loading state, preserving previous data
    state = AsyncLoading<List<Transaction>>().copyWithPrevious(state);
    try {
      await _repository.addTransaction(transaction);
      // After adding, the relevant transactionsStreamProvider will update.
      // This controller's list might also need refresh if it's showing the list where new item belongs.
      await _refreshState();
      // TODO: Trigger recalculation of the affected account's balance.
      // This could be done by invalidating a balance provider or calling a method on FinancialAccountController.
      ref.invalidate(currentBalanceProvider(transaction.affectedAccountId));
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace).copyWithPrevious(state);
      rethrow;
    }
  }

  Future<void> updateTransaction(Transaction transaction) async {
    state = AsyncLoading<List<Transaction>>().copyWithPrevious(state);
    try {
      // We need to know the old affected account if it changed, to update its balance too.
      // For simplicity, this basic version assumes affectedAccountId doesn't change or only updates one.
      await _repository.updateTransaction(transaction);
      await _refreshState();
      ref.invalidate(currentBalanceProvider(transaction.affectedAccountId));
      // If affectedAccountId could change, invalidate old one too.
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace).copyWithPrevious(state);
      rethrow;
    }
  }

  Future<void> deleteTransaction(String supabaseId, Id isarId, String affectedAccountId) async {
    state = AsyncLoading<List<Transaction>>().copyWithPrevious(state);
    try {
      await _repository.deleteTransaction(supabaseId, isarId);
      await _refreshState();
      ref.invalidate(currentBalanceProvider(affectedAccountId));
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace).copyWithPrevious(state);
      rethrow;
    }
  }

  Future<void> syncTransactions({String? accountIdFilter}) async {
    state = AsyncLoading<List<Transaction>>().copyWithPrevious(state);
    try {
      await _repository.syncRemoteToLocal(accountIdFilter: accountIdFilter);
      await _refreshState(); // Refresh this controller's list
      if (accountIdFilter != null) {
        ref.invalidate(currentBalanceProvider(accountIdFilter));
      } else {
        // If syncing all, might need to invalidate all relevant balance providers
        // This is complex; ideally, sync per account or have a global balance update mechanism.
      }
      print("TransactionController: Sync complete for filter '$accountIdFilter'.");
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace).copyWithPrevious(state);
      rethrow;
    }
  }

  Future<void> _refreshState() async {
    // Refreshes the list this controller holds, respecting its internal filter
    try {
      final transactions = await _repository.getTransactionsLocal(accountIdFilter: _currentAccountIdFilter);
      state = AsyncData(transactions);
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace);
    }
  }
}
