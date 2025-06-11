import 'package:fmapp/src/core/data/isar_service.dart';
import 'package:fmapp/src/features/loans/data/models/loan_debt.dart';
import 'package:fmapp/src/features/transactions/data/models/transaction.dart'; // For creating linked transactions
import 'package:fmapp/src/features/transactions/data/repositories/transaction_repository.dart'; // To add transactions
import 'package:fmapp/src/features/friends/data/models/friend.dart'; // To get friend name for transaction description
import 'package:fmapp/src/features/friends/data/repositories/friend_repository.dart'; // To get friend by ID
import 'package:fmapp/main.dart' show supabaseClientProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// Provider for LoanDebtRepository
final loanDebtRepositoryProvider = Provider<LoanDebtRepository>((ref) {
  final isar = ref.watch(isarInstanceProvider);
  final supabaseClient = ref.watch(supabaseClientProvider);
  final transactionRepository = ref.watch(transactionRepositoryProvider); // Dependency
  final friendRepository = ref.watch(friendRepositoryProvider); // Dependency
  return LoanDebtRepository(isar, supabaseClient, const Uuid(), transactionRepository, friendRepository);
});

class LoanDebtRepository {
  final Isar _isar;
  final SupabaseClient _supabase;
  final Uuid _uuid;
  final TransactionRepository _transactionRepository;
  final FriendRepository _friendRepository; // To get friend's name

  LoanDebtRepository(this._isar, this._supabase, this._uuid, this._transactionRepository, this._friendRepository);

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // --- Local Isar Operations ---
  Stream<List<LoanDebt>> watchLoanDebtsLocal({LoanDebtStatus? filterStatus, String? friendId}) {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    var query = _isar.loanDebts.where().userIdEqualTo(userId);
    if (friendId != null) {
      query = query.filter().associatedFriendIdEqualTo(friendId);
    }
    if (filterStatus != null) {
      query = query.filter().statusEqualTo(filterStatus);
    }
    return query.sortByDateInitiatedDesc().watch(fireImmediately: true);
  }

  Future<List<LoanDebt>> getLoanDebtsLocal({LoanDebtStatus? filterStatus, String? friendId}) async {
    final userId = _currentUserId;
    if (userId == null) return [];
     var query = _isar.loanDebts.where().userIdEqualTo(userId);
    if (friendId != null) {
      query = query.filter().associatedFriendIdEqualTo(friendId);
    }
    if (filterStatus != null) {
      query = query.filter().statusEqualTo(filterStatus);
    }
    return query.sortByDateInitiatedDesc().findAll();
  }

  Future<LoanDebt?> getLoanDebtBySupabaseIdLocal(String supabaseId) async {
    return _isar.loanDebts.filter().supabaseIdEqualTo(supabaseId).findFirst();
  }

  Future<Id> saveLoanDebtLocal(LoanDebt loanDebt) async {
    return await _isar.writeTxn(() async {
      return await _isar.loanDebts.put(loanDebt);
    });
  }

  Future<bool> deleteLoanDebtLocal(Id isarId) async {
    // PRD doesn't specify if loans can be deleted. If they create transactions,
    // deleting a loan without handling linked transactions could be problematic.
    // For P0, allow deletion. Consider soft delete or restrictions later.
    return await _isar.writeTxn(() async {
      return await _isar.loanDebts.delete(isarId);
    });
  }

  // --- Supabase Operations ---
  Future<LoanDebt> addLoanDebtRemote(LoanDebt loanDebt) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated.");

    final loanWithSupabaseId = loanDebt.supabaseId == null
        ? loanDebt.copyWith(supabaseId: _uuid.v4(), userId: userId)
        : loanDebt.copyWith(userId: userId);

    final response = await _supabase.from('loan_debts').insert(loanWithSupabaseId.toMap()).select().single();
    return LoanDebt.fromMap(response);
  }

  Future<LoanDebt> updateLoanDebtRemote(LoanDebt loanDebt) async {
    if (loanDebt.supabaseId == null) throw Exception("Supabase ID required for update.");
    final userId = _currentUserId;
    if (userId == null || loanDebt.userId != userId) throw Exception("User cannot update this record.");

    final response = await _supabase.from('loan_debts')
        .update(loanDebt.toMap()..remove('id')..remove('user_id')..remove('created_at'))
        .eq('id', loanDebt.supabaseId!)
        .eq('user_id', userId)
        .select().single();
    return LoanDebt.fromMap(response);
  }

  Future<void> deleteLoanDebtRemote(String supabaseId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated.");
    await _supabase.from('loan_debts').delete().eq('id', supabaseId).eq('user_id', userId);
  }

  Future<List<LoanDebt>> fetchLoanDebtsRemote() async {
    final userId = _currentUserId;
    if (userId == null) return [];
    final response = await _supabase.from('loan_debts').select().eq('user_id', userId).order('date_initiated', ascending: false);
    return response.map((data) => LoanDebt.fromMap(data)).toList();
  }

  // --- Combined Operations ---
  Future<LoanDebt> addLoanDebt(LoanDebt loanDebt) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated.");

    // Ensure outstanding amount is same as initial for a new loan/debt
    final newLoanDebt = loanDebt.copyWith(
        userId: userId,
        outstandingAmount: loanDebt.initialAmount,
        status: LoanDebtStatus.active
    );

    LoanDebt remoteLoanDebt;
    try {
      remoteLoanDebt = await addLoanDebtRemote(newLoanDebt);
    } catch (e) { print("Error adding loan/debt to remote: $e"); rethrow; }

    await saveLoanDebtLocal(remoteLoanDebt);

    // Create linked transaction if initial method is not "Cash"
    if (remoteLoanDebt.initialTransactionMethod.toLowerCase() != "cash") {
      final friend = await _friendRepository.getFriendBySupabaseIdLocal(remoteLoanDebt.associatedFriendId);
      String friendName = friend?.friendName ?? "Friend";
      TransactionType type;
      String description;

      if (remoteLoanDebt.type == LoanDebtType.loanGivenToFriend) {
        type = TransactionType.expenseDebit; // Money leaving my account
        description = "Loan to $friendName${remoteLoanDebt.description != null ? ' (${remoteLoanDebt.description})' : ''}";
      } else { // DebtOwedToFriend
        type = TransactionType.incomeCredit; // Money entering my account
        description = "Borrowed from $friendName${remoteLoanDebt.description != null ? ' (${remoteLoanDebt.description})' : ''}";
      }

      final linkedTransaction = Transaction(
          userId: userId,
          affectedAccountId: remoteLoanDebt.initialTransactionMethod, // This is the FinancialAccount.supabaseId
          transactionDate: remoteLoanDebt.dateInitiated,
          amount: remoteLoanDebt.initialAmount,
          transactionType: type,
          descriptionNotes: description,
          categoryTag: "Loan/Debt", // Or more specific
          createdAt: remoteLoanDebt.createdAt, // Align timestamps
          updatedAt: remoteLoanDebt.updatedAt,
          // supabaseId will be generated by addTransaction
      );
      await _transactionRepository.addTransaction(linkedTransaction);
    }
    return remoteLoanDebt;
  }

  Future<LoanDebt> recordRepayment({
    required LoanDebt loanDebt, // The loan/debt being paid
    required double repaymentAmount,
    required DateTime repaymentDate,
    required String repaymentMethod, // "Cash" or FinancialAccount.supabaseId
    String? notes,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated.");
    if (repaymentAmount <= 0) throw Exception("Repayment amount must be positive.");
    if (repaymentAmount > loanDebt.outstandingAmount) {
      // Or adjust to pay only outstanding, depends on desired behavior
      throw Exception("Repayment amount cannot exceed outstanding amount.");
    }

    final newOutstandingAmount = loanDebt.outstandingAmount - repaymentAmount;
    final newStatus = newOutstandingAmount <= 0 ? LoanDebtStatus.paidOff : LoanDebtStatus.partiallyPaid;

    final updatedLoanDebt = loanDebt.copyWith(
      outstandingAmount: newOutstandingAmount,
      status: newStatus,
      updatedAt: DateTime.now(),
    );

    LoanDebt remoteUpdatedLoanDebt;
    try {
      remoteUpdatedLoanDebt = await updateLoanDebtRemote(updatedLoanDebt);
    } catch (e) { print("Error updating loan/debt on remote for repayment: $e"); rethrow; }

    await saveLoanDebtLocal(remoteUpdatedLoanDebt);

    // Create linked transaction for repayment if method is not "Cash"
    if (repaymentMethod.toLowerCase() != "cash") {
      final friend = await _friendRepository.getFriendBySupabaseIdLocal(remoteUpdatedLoanDebt.associatedFriendId);
      String friendName = friend?.friendName ?? "Friend";
      TransactionType type;
      String description;

      if (remoteUpdatedLoanDebt.type == LoanDebtType.loanGivenToFriend) { // I lent money, friend is repaying me
        type = TransactionType.incomeCredit; // Money coming into my account
        description = "Repayment from $friendName for loan${notes != null ? ' ($notes)' : ''}";
      } else { // DebtOwedToFriend - I borrowed money, I am repaying friend
        type = TransactionType.expenseDebit; // Money leaving my account
        description = "Repayment to $friendName for debt${notes != null ? ' ($notes)' : ''}";
      }

      final linkedTransaction = Transaction(
        userId: userId,
        affectedAccountId: repaymentMethod, // This is the FinancialAccount.supabaseId used for repayment
        transactionDate: repaymentDate,
        amount: repaymentAmount,
        transactionType: type,
        descriptionNotes: description,
        categoryTag: "Loan Repayment",
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _transactionRepository.addTransaction(linkedTransaction);
    }
    return remoteUpdatedLoanDebt;
  }


  Future<void> deleteLoanDebt(String supabaseId, Id isarId) async {
    // Consider implications: if transactions were linked, they remain.
    // User might need to manually delete/adjust them.
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated.");
    try {
      await deleteLoanDebtRemote(supabaseId);
    } catch (e) { print("Error deleting loan/debt from remote: $e"); rethrow; }
    await deleteLoanDebtLocal(isarId);
  }

  Future<void> syncRemoteToLocal() async {
    final userId = _currentUserId;
    if (userId == null) return;
    print("Syncing loan/debts from remote to local...");
    final remoteLoanDebts = await fetchLoanDebtsRemote();
    await _isar.writeTxn(() async {
      final localUserLoanDebts = await _isar.loanDebts.where().userIdEqualTo(userId).findAll();
      await _isar.loanDebts.deleteAll(localUserLoanDebts.map((l) => l.isarId).toList());
      if (remoteLoanDebts.isNotEmpty) {
        await _isar.loanDebts.putAll(remoteLoanDebts);
      }
    });
    print("Sync complete. Found ${remoteLoanDebts.length} loan/debts on remote.");
  }
}

// Helper extension for sorting LoanDebt by dateInitiated
extension QueryBuilderSortByLoanDate<T, R, S> on QueryBuilder<T, R, S> {
    QueryBuilder<T, R, QAfterSortBy> sortByDateInitiatedDesc() {
        return QueryBuilder.apply(this, (query) => query.sortByDesc(r'dateInitiated'));
    }
    QueryBuilder<T, R, QAfterSortBy> sortByDateInitiated() {
        return QueryBuilder.apply(this, (query) => query.sortBy(r'dateInitiated'));
    }
}
