import 'package:fmapp/src/core/data/isar_service.dart';
import 'package:fmapp/src/features/transactions/data/models/transaction.dart';
import 'package:fmapp/main.dart' show supabaseClientProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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

    // If accountIdFilter is provided, we want transactions where EITHER
    // affectedAccountId OR counterpartyAccountId matches the filter,
    // to show all transactions involving that account (sends and receives for transfers).
    if (accountIdFilter != null && accountIdFilter.isNotEmpty) {
      return _isar.transactions.where()
          .userIdEqualTo(userId)
          .filter()
          .group((q) => q.affectedAccountIdEqualTo(accountIdFilter)
                       .or()
                       .counterpartyAccountIdEqualTo(accountIdFilter)
          )
          .sortByTransactionDateDesc()
          .watch(fireImmediately: true);
    } else {
      // No account filter, return all transactions for the user
      return _isar.transactions.where()
          .userIdEqualTo(userId)
          .sortByTransactionDateDesc()
          .watch(fireImmediately: true);
    }
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

    var filterQuery = query.filter();

    if (accountIdFilter != null && accountIdFilter.isNotEmpty) {
      filterQuery = filterQuery.group((q) =>
          q.affectedAccountIdEqualTo(accountIdFilter)
           .or()
           .counterpartyAccountIdEqualTo(accountIdFilter)
      );
    }
    if (startDate != null) {
      filterQuery = filterQuery.transactionDateGreaterThan(startDate.subtract(const Duration(microseconds: 1)));
    }
    if (endDate != null) {
      filterQuery = filterQuery.transactionDateLessThan(endDate.add(const Duration(days: 1)));
    }

    var finalQuery = filterQuery.build();

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
  // (addTransactionRemote, updateTransactionRemote, deleteTransactionRemote, fetchTransactionsRemote
  // will implicitly handle new fields because transaction.toMap() includes them)

  Future<Transaction> addTransactionRemote(Transaction transaction) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated.");

    final transactionWithSupabaseId = transaction.supabaseId == null
        ? transaction.copyWith(supabaseId: _uuid.v4(), userId: userId)
        : transaction.copyWith(userId: userId);

    final response = await _supabase
        .from('transactions')
        .insert(transactionWithSupabaseId.toMap()) // .toMap() now includes new fields
        .select()
        .single();

    return Transaction.fromMap(response);
  }

  Future<Transaction> updateTransactionRemote(Transaction transaction) async {
    if (transaction.supabaseId == null) throw Exception("Supabase ID required for update.");
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
    if (userId == null) throw Exception("User not authenticated.");
    await _supabase.from('transactions').delete().eq('id', supabaseId).eq('user_id', userId);
  }

  Future<List<Transaction>> fetchTransactionsRemote({String? accountIdFilter}) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    var query = _supabase.from('transactions').select().eq('user_id', userId);

    if (accountIdFilter != null && accountIdFilter.isNotEmpty) {
      // Fetch transactions where the account is either source or destination for transfers
      query = query.or('affected_account_id.eq.$accountIdFilter,and(is_internal_transfer.is.true,counterparty_account_id.eq.$accountIdFilter)');
    }
    query = query.order('transaction_date', ascending: false);


    final response = await query;
    return response.map((data) => Transaction.fromMap(data)).toList();
  }

  // --- Combined Operations ---
  Future<Transaction> addTransaction(Transaction transaction) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated.");

    // PRD 4.4.1: "automated double-entry logic" OR "visually distinct...NOT affect total net worth"
    // The current model with isInternalTransfer flag and counterpartyAccountId supports the latter.
    // The 'amount' is debited from affectedAccountId and credited to counterpartyAccountId for balance calculation.
    // No separate transaction record is automatically created by the repository for the other "leg".
    // The single transaction record represents the entire transfer.
    // If transactionType for a transfer is always e.g. 'expenseDebit', it refers to the source account.

    Transaction remoteTransaction;
    try {
      Transaction transactionToRemote = transaction.copyWith(userId: userId);
      if (transactionToRemote.supabaseId == null) {
          transactionToRemote = transactionToRemote.copyWith(supabaseId: _uuid.v4());
      }
      remoteTransaction = await addTransactionRemote(transactionToRemote);
    } catch (e) {
      print("Error adding transaction to remote: $e");
      rethrow;
    }
    await saveTransactionLocal(remoteTransaction);
    return remoteTransaction;
  }

  Future<Transaction> updateTransaction(Transaction transaction) async {
    // ... (similar to add, existing logic should mostly work due to toMap including new fields)
    final userId = _currentUserId;
    if (userId == null || transaction.supabaseId == null) throw Exception("Auth or ID error.");
    if (transaction.userId != userId) throw Exception("User mismatch.");

    Transaction updatedRemoteTransaction;
    try {
      updatedRemoteTransaction = await updateTransactionRemote(transaction);
    } catch (e) { rethrow; }
    await saveTransactionLocal(updatedRemoteTransaction);
    return updatedRemoteTransaction;
  }

  Future<void> deleteTransaction(String supabaseId, Id isarId) async {
    // ... (existing logic works)
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated.");
    try {
      await deleteTransactionRemote(supabaseId);
    } catch (e) { rethrow; }
    await deleteTransactionLocal(isarId);
  }

  Future<void> syncRemoteToLocal({String? accountIdFilter}) async {
    final userId = _currentUserId;
    if (userId == null) return;

    print("Syncing transactions from remote to local (filter: $accountIdFilter)...");
    final remoteTransactions = await fetchTransactionsRemote(accountIdFilter: accountIdFilter);

    await _isar.writeTxn(() async {
      if (accountIdFilter != null && accountIdFilter.isNotEmpty) {
        final localFilteredTransactions = await _isar.transactions.where()
            .userIdEqualTo(userId)
            .filter()
            .group((q) => q.affectedAccountIdEqualTo(accountIdFilter).or().counterpartyAccountIdEqualTo(accountIdFilter))
            .findAll();
        final List<Id> idsToDelete = localFilteredTransactions.map((t) => t.isarId).toList();
        if (idsToDelete.isNotEmpty) await _isar.transactions.deleteAll(idsToDelete);
      } else {
        final allUserLocalTransactions = await _isar.transactions.where().userIdEqualTo(userId).findAll();
        final List<Id> idsToDelete = allUserLocalTransactions.map((t) => t.isarId).toList();
         if (idsToDelete.isNotEmpty) await _isar.transactions.deleteAll(idsToDelete);
      }

      if (remoteTransactions.isNotEmpty) await _isar.transactions.putAll(remoteTransactions);
    });
    print("Sync complete. Found ${remoteTransactions.length} transactions for filter.");
  }
}
