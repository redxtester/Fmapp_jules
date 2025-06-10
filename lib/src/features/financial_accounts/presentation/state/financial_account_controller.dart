import 'dart:async';
import 'package:fmapp/src/features/financial_accounts/data/models/financial_account.dart';
import 'package:fmapp/src/features/financial_accounts/data/repositories/financial_account_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart'; // For Id type

// Provider for FinancialAccountController
final financialAccountControllerProvider =
    AsyncNotifierProvider<FinancialAccountController, List<FinancialAccount>>(() {
  return FinancialAccountController();
});

// Provider to watch a stream of Financial Accounts (local first, then potentially synced)
// This directly uses the repository's local watch stream.
// It can be further customized, e.g., by passing a filter for archived accounts.
final financialAccountsStreamProvider = StreamProvider.autoDisposeFamily<List<FinancialAccount>, bool>((ref, includeArchived) {
  final repository = ref.watch(financialAccountRepositoryProvider);
  return repository.watchFinancialAccountsLocal(includeArchived: includeArchived);
});


class FinancialAccountController extends AsyncNotifier<List<FinancialAccount>> {
  late FinancialAccountRepository _repository;
  // Default to not showing archived accounts in the controller's main list state.
  // UI can use financialAccountsStreamProvider(true) for archived views.
  bool _includeArchivedInState = false;

  @override
  Future<List<FinancialAccount>> build() async {
    _repository = ref.watch(financialAccountRepositoryProvider);
    // Optional: Trigger an initial sync when the controller is first built
    // Future.microtask(() => syncFinancialAccounts()); // Non-blocking sync
    return _repository.getFinancialAccountsLocal(includeArchived: _includeArchivedInState);
  }

  Future<void> addFinancialAccount(FinancialAccount account) async {
    state = const AsyncLoading();
    try {
      await _repository.addFinancialAccount(account);
      await _refreshState();
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace);
      rethrow;
    }
  }

  Future<void> updateFinancialAccount(FinancialAccount account) async {
    state = const AsyncLoading();
    try {
      await _repository.updateFinancialAccount(account);
      await _refreshState();
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace);
      rethrow;
    }
  }

  Future<void> toggleArchiveFinancialAccount(FinancialAccount account) async {
    // No loading state here, as it's an update that should feel quick.
    // The stream provider will reflect the change instantly from local DB.
    // This controller's state will refresh too.
    try {
      await _repository.toggleArchiveFinancialAccount(account);
      await _refreshState(); // Refresh to reflect change if list filters by isArchived
    } catch (e, stackTrace) {
      // If state was AsyncLoading, it would be AsyncError.
      // Here, we might want to handle error differently if not using global loading.
      // For now, just rethrow to UI.
      print("Error toggling archive status: $e");
      state = AsyncError(e, stackTrace); // Set error state if needed
      rethrow;
    }
  }

  Future<void> deleteFinancialAccount(String supabaseId, Id isarId) async {
    state = const AsyncLoading();
    try {
      await _repository.deleteFinancialAccount(supabaseId, isarId);
      await _refreshState();
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace);
      rethrow;
    }
  }

  Future<void> syncFinancialAccounts() async {
    // Set state to loading, but preserve current data if available
    state = AsyncLoading<List<FinancialAccount>>().copyWithPrevious(state);
    try {
      await _repository.syncRemoteToLocal();
      // Stream provider will update UI. This controller's state also refreshed.
      await _refreshState();
      print("FinancialAccountController: Sync complete, state refreshed.");
    } catch (e, stackTrace) {
      print("FinancialAccountController: Sync error: $e");
      state = AsyncError(e, stackTrace).copyWithPrevious(state); // Preserve data on error
      rethrow;
    }
  }

  // Helper to refresh the list state based on current filter
  Future<void> _refreshState() async {
    try {
      final currentSims = await _repository.getFinancialAccountsLocal(includeArchived: _includeArchivedInState);
      state = AsyncData(currentSims);
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace);
    }
  }

  // Optional: method to change the filter for this controller's state
  void setIncludeArchivedFilter(bool includeArchived) {
    _includeArchivedInState = includeArchived;
    state = const AsyncLoading(); // Show loading while refiltering
    _refreshState();
  }
}
