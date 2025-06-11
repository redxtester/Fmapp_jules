import 'dart:async';
import 'package:fmapp/src/features/transactions/data/models/transaction.dart';
import 'package:fmapp/src/features/transactions/data/repositories/transaction_repository.dart';
import 'package:fmapp/src/features/financial_accounts/data/models/financial_account.dart';
import 'package:fmapp/src/features/financial_accounts/data/repositories/financial_account_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

final transactionControllerProvider =
    AsyncNotifierProvider<TransactionController, List<Transaction>>(() {
  return TransactionController();
});

final transactionsStreamProvider =
    StreamProvider.autoDispose.family<List<Transaction>, String?>((ref, accountId) {
  final repository = ref.watch(transactionRepositoryProvider);
  // The repository's watchTransactionsLocal was updated to fetch if affected or counterparty
  return repository.watchTransactionsLocal(accountId);
});

final singleFinancialAccountStreamProvider =
    StreamProvider.autoDispose.family<FinancialAccount?, String>((ref, accountSupabaseId) {
  final accountRepo = ref.watch(financialAccountRepositoryProvider);
  return accountRepo.watchFinancialAccountBySupabaseIdLocal(accountSupabaseId);
});

final currentBalanceProvider = Provider.autoDispose.family<double, String>((ref, accountSupabaseId) {
  // Watch all transactions involving this account (as source or destination for transfers)
  final transactionsAsyncValue = ref.watch(transactionsStreamProvider(accountSupabaseId));
  final accountAsyncValue = ref.watch(singleFinancialAccountStreamProvider(accountSupabaseId));

  final account = accountAsyncValue.value;
  final transactions = transactionsAsyncValue.value ?? [];

  if (account == null) {
    return 0.0;
  }

  double currentBalance = account.initialBalance;

  for (var tx in transactions) {
    // Skip transactions dated before the account was added by the user.
    // This prevents transactions from a previous use of an account number (e.g. if re-added)
    // from affecting a newly added account instance in the app with a later 'dateAdded'.
    // PRD 4.2.1: initialBalance, dateAdded.
    if (tx.transactionDate.isBefore(account.dateAdded)) {
        // For Isar, date comparison needs to be careful with timezones if not UTC.
        // Assuming dates are consistent (e.g. all stored as UTC or all local but consistent).
        // For simplicity, direct comparison.
        continue;
    }

    if (tx.isInternalTransfer) {
      if (tx.affectedAccountId == accountSupabaseId) {
        // This account is the SOURCE of the transfer (debit)
        currentBalance -= tx.amount;
      } else if (tx.counterpartyAccountId == accountSupabaseId) {
        // This account is the DESTINATION of the transfer (credit)
        currentBalance += tx.amount;
      }
    } else { // Regular income or expense
      if (tx.affectedAccountId == accountSupabaseId) { // Ensure transaction belongs to this account
          if (tx.transactionType == TransactionType.incomeCredit) {
            currentBalance += tx.amount;
          } else if (tx.transactionType == TransactionType.expenseDebit) {
            currentBalance -= tx.amount;
          }
      }
    }
  }
  return currentBalance;
});


class TransactionController extends AsyncNotifier<List<Transaction>> {
  late TransactionRepository _repository;
  String? _currentAccountIdFilter;

  @override
  Future<List<Transaction>> build() async {
    _repository = ref.watch(transactionRepositoryProvider);
    return _repository.getTransactionsLocal(accountIdFilter: _currentAccountIdFilter);
  }

  void setAccountIdFilter(String? accountId) {
    _currentAccountIdFilter = accountId;
    _refreshState();
  }

  Future<void> addTransaction(Transaction transaction) async {
    state = AsyncLoading<List<Transaction>>().copyWithPrevious(state);
    try {
      await _repository.addTransaction(transaction);
      await _refreshState();
      // Invalidate balance for affected account
      ref.invalidate(currentBalanceProvider(transaction.affectedAccountId));
      // If it's an internal transfer, also invalidate for counterparty account
      if (transaction.isInternalTransfer && transaction.counterpartyAccountId != null) {
        ref.invalidate(currentBalanceProvider(transaction.counterpartyAccountId!));
      }
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace).copyWithPrevious(state);
      rethrow;
    }
  }

  Future<void> updateTransaction(Transaction transaction, String oldAffectedAccountId, String? oldCounterpartyAccountId, bool wasInternalTransfer) async {
    state = AsyncLoading<List<Transaction>>().copyWithPrevious(state);
    try {
      await _repository.updateTransaction(transaction);
      await _refreshState();

      // Invalidate current affected account
      ref.invalidate(currentBalanceProvider(transaction.affectedAccountId));
      // Invalidate old affected account if it changed
      if (oldAffectedAccountId != transaction.affectedAccountId) {
        ref.invalidate(currentBalanceProvider(oldAffectedAccountId));
      }

      // Handle counterparty invalidation for current and previous states
      if (transaction.isInternalTransfer && transaction.counterpartyAccountId != null) {
        ref.invalidate(currentBalanceProvider(transaction.counterpartyAccountId!));
      }
      if (wasInternalTransfer && oldCounterpartyAccountId != null) {
        // If it was a transfer and counterparty changed or it's no longer a transfer
        if (oldCounterpartyAccountId != transaction.counterpartyAccountId || !transaction.isInternalTransfer) {
             ref.invalidate(currentBalanceProvider(oldCounterpartyAccountId));
        }
      }

    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace).copyWithPrevious(state);
      rethrow;
    }
  }

  Future<void> deleteTransaction(Transaction transactionToDelete) async {
    state = AsyncLoading<List<Transaction>>().copyWithPrevious(state);
    try {
      if (transactionToDelete.supabaseId == null) throw Exception("Cannot delete unsynced transaction by this method.");
      await _repository.deleteTransaction(transactionToDelete.supabaseId!, transactionToDelete.isarId);
      await _refreshState();

      ref.invalidate(currentBalanceProvider(transactionToDelete.affectedAccountId));
      if (transactionToDelete.isInternalTransfer && transactionToDelete.counterpartyAccountId != null) {
        ref.invalidate(currentBalanceProvider(transactionToDelete.counterpartyAccountId!));
      }
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
        // If syncing all, need a way to know which accounts were affected to invalidate.
        // This is complex. For now, user might need to visit account to see updated balance,
        // or a global "refresh all balances" event could be triggered.
        // Or, the financialAccountsStreamProvider could be invalidated to refresh all account views.
        // ref.invalidate(financialAccountsStreamProvider(false)); // This would cause mass rebuild
        // ref.invalidate(financialAccountsStreamProvider(true));
      }
      print("TransactionController: Sync complete for filter '$accountIdFilter'.");
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace).copyWithPrevious(state);
      rethrow;
    }
  }

  Future<void> _refreshState() async {
    try {
      final transactions = await _repository.getTransactionsLocal(accountIdFilter: _currentAccountIdFilter);
      state = AsyncData(transactions);
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace);
    }
  }
}
