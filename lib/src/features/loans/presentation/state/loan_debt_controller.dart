import 'dart:async';
import 'package:fmapp/src/features/loans/data/models/loan_debt.dart';
import 'package:fmapp/src/features/loans/data/repositories/loan_debt_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart'; // For Id type

// Provider for LoanDebtController
final loanDebtControllerProvider =
    AsyncNotifierProvider<LoanDebtController, List<LoanDebt>>(() {
  return LoanDebtController();
});

// Stream provider for loans/debts, family by status and friendId (both optional)
// This allows flexible filtering in the UI.
// For simplicity, we might start with a less complex family or multiple specific providers.
// Let's make a family provider that takes a filter object.

class LoanDebtFilter {
  final LoanDebtStatus? status;
  final String? friendId;
  // Add other filters like type (loan/debt) if needed

  const LoanDebtFilter({this.status, this.friendId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoanDebtFilter &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          friendId == other.friendId;

  @override
  int get hashCode => status.hashCode ^ friendId.hashCode;
}

final loanDebtsStreamProvider =
    StreamProvider.autoDispose.family<List<LoanDebt>, LoanDebtFilter>((ref, filter) {
  final repository = ref.watch(loanDebtRepositoryProvider);
  return repository.watchLoanDebtsLocal(filterStatus: filter.status, friendId: filter.friendId);
});


class LoanDebtController extends AsyncNotifier<List<LoanDebt>> {
  late LoanDebtRepository _repository;
  // Internal filter for the controller's own list state, if needed beyond what build args provide.
  LoanDebtFilter _currentListFilter = const LoanDebtFilter();

  @override
  Future<List<LoanDebt>> build() async {
    _repository = ref.watch(loanDebtRepositoryProvider);
    // Optionally sync on first build or based on some other logic
    // Future.microtask(() => syncLoanDebts());
    return _repository.getLoanDebtsLocal(
        filterStatus: _currentListFilter.status,
        friendId: _currentListFilter.friendId
    );
  }

  // Method to apply filter to this controller's managed list if it holds one.
  // However, UIs will likely use the loanDebtsStreamProvider with specific filters.
  void applyListFilter(LoanDebtFilter filter) {
    _currentListFilter = filter;
    state = const AsyncLoading(); // Show loading while refiltering
    _refreshState();
  }

  Future<void> addLoanDebt(LoanDebt loanDebt) async {
    state = const AsyncLoading<List<LoanDebt>>().copyWithPrevious(state);
    try {
      await _repository.addLoanDebt(loanDebt);
      await _refreshState();
      // Invalidate transaction related providers as new transactions are created
      // This is handled by TransactionController when its addTransaction is called.
      // If TransactionController is not used by LoanDebtRepository directly, then
      // LoanDebtRepository's addTransaction should ensure balance providers are invalidated.
      // The current LoanDebtRepository calls _transactionRepository.addTransaction which should handle it.
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace).copyWithPrevious(state);
      rethrow;
    }
  }

  Future<void> recordRepayment({
    required LoanDebt loanDebt,
    required double repaymentAmount,
    required DateTime repaymentDate,
    required String repaymentMethod, // "Cash" or FinancialAccount.supabaseId
    String? notes,
  }) async {
    state = const AsyncLoading<List<LoanDebt>>().copyWithPrevious(state);
    try {
      await _repository.recordRepayment(
        loanDebt: loanDebt,
        repaymentAmount: repaymentAmount,
        repaymentDate: repaymentDate,
        repaymentMethod: repaymentMethod,
        notes: notes,
      );
      await _refreshState();
      // Balance invalidation for repayment transaction is handled by TransactionController.
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace).copyWithPrevious(state);
      rethrow;
    }
  }

  Future<void> updateLoanDebt(LoanDebt loanDebt) async {
    // Generally, loans are updated via repayments. This might be for editing description/dueDate.
    state = const AsyncLoading<List<LoanDebt>>().copyWithPrevious(state);
    try {
      await _repository.updateLoanDebtRemote(loanDebt); // Assuming direct remote update for non-repayment changes
      await _repository.saveLoanDebtLocal(loanDebt); // then save to local
      await _refreshState();
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace).copyWithPrevious(state);
      rethrow;
    }
  }


  Future<void> deleteLoanDebt(String supabaseId, Id isarId) async {
    state = const AsyncLoading<List<LoanDebt>>().copyWithPrevious(state);
    try {
      await _repository.deleteLoanDebt(supabaseId, isarId);
      await _refreshState();
      // Deleting a loan might revert initial transactions or require manual adjustment.
      // Current setup doesn't automatically delete linked transactions.
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace).copyWithPrevious(state);
      rethrow;
    }
  }

  Future<void> syncLoanDebts() async {
    state = const AsyncLoading<List<LoanDebt>>().copyWithPrevious(state);
    try {
      await _repository.syncRemoteToLocal();
      await _refreshState();
      print("LoanDebtController: Sync complete, state refreshed.");
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace).copyWithPrevious(state);
      rethrow;
    }
  }

  Future<void> _refreshState() async {
    try {
      final currentItems = await _repository.getLoanDebtsLocal(
          filterStatus: _currentListFilter.status,
          friendId: _currentListFilter.friendId
      );
      state = AsyncData(currentItems);
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace).copyWithPrevious(state);
    }
  }
}
