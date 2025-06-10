import 'package:fmapp/src/core/data/isar_service.dart';
import 'package:fmapp/src/features/transactions/data/models/transaction.dart';
// Assuming supabaseClientProvider is defined in main.dart or similar
import 'package:fmapp/main.dart' show supabaseClientProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// Provider for TransactionRepository
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final isar = ref.watch(isarInstanceProvider);
  final supabaseClient = ref.watch(supabaseClientProvider);
  return TransactionRepository(isar, supabaseClient, const Uuid());
});

class TransactionRepository {
  final Isar _isar;
  final SupabaseClient _supabase;
  final Uuid _uuid;

  TransactionRepository(this._isar, this._supabase, this._uuid);

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // --- Local Isar Operations ---

  Stream<List<Transaction>> watchTransactionsLocal(String? accountIdFilter) {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    QueryBuilder<Transaction, Transaction, QAfterSortBy> query =
        _isar.transactions.where().userIdEqualTo(userId).sortByTransactionDateDesc();

    if (accountIdFilter != null && accountIdFilter.isNotEmpty) {
        query = _isar.transactions.where()
                .userIdEqualTo(userId)
                .filter()
                .affectedAccountIdEqualTo(accountIdFilter)
                .sortByTransactionDateDesc();
    }
    return query.watch(fireImmediately: true);
  }

  Future<List<Transaction>> getTransactionsLocal({
    String? accountIdFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    QueryBuilder<Transaction, Transaction, QSortBy> query =
        _isar.transactions.where().userIdEqualTo(userId).sortByTransactionDateDesc();

    var filterQuery = query.filter(); // Start filter group

    if (accountIdFilter != null && accountIdFilter.isNotEmpty) {
      filterQuery = filterQuery.affectedAccountIdEqualTo(accountIdFilter);
    }
    if (startDate != null) {
      filterQuery = filterQuery.transactionDateGreaterThan(startDate.subtract(const Duration(microseconds: 1)));
    }
    if (endDate != null) {
      filterQuery = filterQuery.transactionDateLessThan(endDate.add(const Duration(days: 1))); // Inclusive of end date
    }

    var finalQuery = filterQuery.build(); // Apply filters

    if (offset != null) finalQuery = finalQuery.offset(offset);
    if (limit != null) finalQuery = finalQuery.limit(limit);

    return await finalQuery.findAll();
  }

  Future<Transaction?> getTransactionBySupabaseIdLocal(String supabaseId) async {
    return _isar.transactions.filter().supabaseIdEqualTo(supabaseId).findFirst();
  }

  Future<Id> saveTransactionLocal(Transaction transaction) async {
    return await _isar.writeTxn(() async {
      return await _isar.transactions.put(transaction);
    });
  }

  Future<bool> deleteTransactionLocal(Id isarId) async {
    return await _isar.writeTxn(() async {
      return await _isar.transactions.delete(isarId);
    });
  }

  // --- Supabase Operations ---

  Future<Transaction> addTransactionRemote(Transaction transaction) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated to add transaction remotely.");

    final transactionWithSupabaseId = transaction.supabaseId == null
        ? transaction.copyWith(supabaseId: _uuid.v4(), userId: userId)
        : transaction.copyWith(userId: userId);

    final response = await _supabase
        .from('transactions')
        .insert(transactionWithSupabaseId.toMap())
        .select()
        .single();

    return Transaction.fromMap(response);
  }

  Future<Transaction> updateTransactionRemote(Transaction transaction) async {
    if (transaction.supabaseId == null) throw Exception("Supabase ID is required to update transaction remotely.");
    final userId = _currentUserId;
    if (userId == null || transaction.userId != userId) throw Exception("User cannot update this transaction.");

    final response = await _supabase
        .from('transactions')
        .update(transaction.toMap()..remove('id')..remove('user_id')..remove('created_at'))
        .eq('id', transaction.supabaseId!)
        .eq('user_id', userId)
        .select()
        .single();

    return Transaction.fromMap(response);
  }

  Future<void> deleteTransactionRemote(String supabaseId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated to delete transaction remotely.");

    await _supabase
        .from('transactions')
        .delete()
        .eq('id', supabaseId)
        .eq('user_id', userId);
  }

  Future<List<Transaction>> fetchTransactionsRemote({String? accountIdFilter}) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    var query = _supabase
        .from('transactions')
        .select()
        .eq('user_id', userId)
        .order('transaction_date', ascending: false);

    if (accountIdFilter != null && accountIdFilter.isNotEmpty) {
      query = query.eq('affected_account_id', accountIdFilter);
    }

    final response = await query;
    return response.map((data) => Transaction.fromMap(data)).toList();
  }

  // --- Combined Operations with Basic Sync Logic ---

  Future<Transaction> addTransaction(Transaction transaction) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated.");

    Transaction remoteTransaction;
    try {
      Transaction transactionToRemote = transaction.copyWith(userId: userId);
      if (transactionToRemote.supabaseId == null) {
          transactionToRemote = transactionToRemote.copyWith(supabaseId: _uuid.v4());
      }
      remoteTransaction = await addTransactionRemote(transactionToRemote);
      // TODO: Update FinancialAccount.currentBalance (or trigger recalculation)
      // This logic will likely live in a domain service or be handled by UI layer based on PRD.
    } catch (e) {
      print("Error adding transaction to remote: $e");
      rethrow;
    }
    await saveTransactionLocal(remoteTransaction);
    return remoteTransaction;
  }

  Future<Transaction> updateTransaction(Transaction transaction) async {
    final userId = _currentUserId;
    if (userId == null || transaction.supabaseId == null) {
      throw Exception("User not authenticated or Supabase ID missing for update.");
    }
    if (transaction.userId != userId) throw Exception("Cannot update transaction not belonging to current user.");

    Transaction updatedRemoteTransaction;
    try {
      updatedRemoteTransaction = await updateTransactionRemote(transaction);
      // TODO: Update FinancialAccount.currentBalance
    } catch (e) {
      print("Error updating transaction on remote: $e");
      rethrow;
    }
    await saveTransactionLocal(updatedRemoteTransaction);
    return updatedRemoteTransaction;
  }

  Future<void> deleteTransaction(String supabaseId, Id isarId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated.");

    try {
      await deleteTransactionRemote(supabaseId);
      // TODO: Update FinancialAccount.currentBalance
    } catch (e) {
      print("Error deleting transaction from remote: $e");
      rethrow;
    }
    await deleteTransactionLocal(isarId);
  }

  Future<void> syncRemoteToLocal({String? accountIdFilter}) async {
    final userId = _currentUserId;
    if (userId == null) return;

    print("Syncing transactions from remote to local (filter: $accountIdFilter)...");
    final remoteTransactions = await fetchTransactionsRemote(accountIdFilter: accountIdFilter);

    await _isar.writeTxn(() async {
      // More targeted sync: only clear/replace for the given account filter if provided.
      // If no filter, sync all user's transactions.
      if (accountIdFilter != null && accountIdFilter.isNotEmpty) {
        final localFilteredTransactions = await _isar.transactions.where()
            .userIdEqualTo(userId)
            .filter()
            .affectedAccountIdEqualTo(accountIdFilter)
            .findAll();
        final List<Id> idsToDelete = localFilteredTransactions.map((t) => t.isarId).toList();
        if (idsToDelete.isNotEmpty) {
          await _isar.transactions.deleteAll(idsToDelete);
        }
      } else {
        // No account filter, sync all transactions for the user (more complex to manage without conflicts)
        // For simplicity, this might mean clearing all user's transactions and re-adding.
        // This is a basic sync, more advanced would involve proper diffing.
        final allUserLocalTransactions = await _isar.transactions.where().userIdEqualTo(userId).findAll();
        final List<Id> idsToDelete = allUserLocalTransactions.map((t) => t.isarId).toList();
         if (idsToDelete.isNotEmpty) {
          await _isar.transactions.deleteAll(idsToDelete);
        }
      }

      if (remoteTransactions.isNotEmpty) {
        await _isar.transactions.putAll(remoteTransactions);
      }
    });
    print("Sync complete. Found ${remoteTransactions.length} transactions on remote for filter.");
    // TODO: Trigger balance recalculation for affected accounts
  }
}
