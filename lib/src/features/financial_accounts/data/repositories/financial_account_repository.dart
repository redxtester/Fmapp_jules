import 'package:fmapp/src/core/data/isar_service.dart';
import 'package:fmapp/src/features/financial_accounts/data/models/financial_account.dart';
// Assuming supabaseClientProvider is defined in main.dart or similar
import 'package:fmapp/main.dart' show supabaseClientProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// Provider for FinancialAccountRepository
final financialAccountRepositoryProvider = Provider<FinancialAccountRepository>((ref) {
  final isar = ref.watch(isarInstanceProvider);
  final supabaseClient = ref.watch(supabaseClientProvider);
  // We need the current user's ID for most operations.
  // It's better if this is passed into methods or obtained from a reliable auth state provider.
  // For now, accessing directly, but this has limitations (e.g. in background tasks if auth state changes).
  return FinancialAccountRepository(isar, supabaseClient, const Uuid());
});

class FinancialAccountRepository {
  final Isar _isar;
  final SupabaseClient _supabase;
  final Uuid _uuid;

  FinancialAccountRepository(this._isar, this._supabase, this._uuid);

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // --- Local Isar Operations ---

  Stream<List<FinancialAccount>> watchFinancialAccountsLocal({bool includeArchived = false}) {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);
    QueryBuilder<FinancialAccount, FinancialAccount, QAfterFilterCondition> query =
        _isar.financialAccounts.where().userIdEqualTo(userId);

    if (!includeArchived) {
      query = query.filter().isArchivedEqualTo(false);
    }
    return query.watch(fireImmediately: true);
  }

  Future<List<FinancialAccount>> getFinancialAccountsLocal({bool includeArchived = false}) async {
    final userId = _currentUserId;
    if (userId == null) return [];
    QueryBuilder<FinancialAccount, FinancialAccount, QAfterFilterCondition> query =
        _isar.financialAccounts.where().userIdEqualTo(userId);

    if (!includeArchived) {
      query = query.filter().isArchivedEqualTo(false);
    }
    return query.findAll();
  }

  Future<FinancialAccount?> getFinancialAccountBySupabaseIdLocal(String supabaseId) async {
    return _isar.financialAccounts.filter().supabaseIdEqualTo(supabaseId).findFirst();
  }

  Future<Id> saveFinancialAccountLocal(FinancialAccount account) async {
    return await _isar.writeTxn(() async {
      return await _isar.financialAccounts.put(account);
    });
  }

  Future<bool> deleteFinancialAccountLocal(Id isarId) async {
    // Note: Consider implications: what happens to transactions linked to this account?
    // PRD doesn't specify cascading deletes for transactions from account deletion.
    // For now, direct deletion.
    return await _isar.writeTxn(() async {
      return await _isar.financialAccounts.delete(isarId);
    });
  }

  // --- Supabase Operations ---

  Future<FinancialAccount> addFinancialAccountRemote(FinancialAccount account) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated to add account remotely.");

    final accountWithSupabaseId = account.supabaseId == null
        ? account.copyWith(supabaseId: _uuid.v4(), userId: userId)
        : account.copyWith(userId: userId);

    final response = await _supabase
        .from('financial_accounts')
        .insert(accountWithSupabaseId.toMap())
        .select()
        .single();

    return FinancialAccount.fromMap(response);
  }

  Future<FinancialAccount> updateFinancialAccountRemote(FinancialAccount account) async {
    if (account.supabaseId == null) throw Exception("Supabase ID is required to update account remotely.");
    final userId = _currentUserId;
    if (userId == null || account.userId != userId) throw Exception("User cannot update this account.");

    final response = await _supabase
        .from('financial_accounts')
        .update(account.toMap()..remove('id')..remove('user_id')..remove('created_at'))
        .eq('id', account.supabaseId!)
        .eq('user_id', userId)
        .select()
        .single();

    return FinancialAccount.fromMap(response);
  }

  Future<void> deleteFinancialAccountRemote(String supabaseId) async {
    // See note on deleteFinancialAccountLocal regarding transactions.
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated to delete account remotely.");

    await _supabase
        .from('financial_accounts')
        .delete()
        .eq('id', supabaseId)
        .eq('user_id', userId);
  }

  Future<List<FinancialAccount>> fetchFinancialAccountsRemote() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    final response = await _supabase
        .from('financial_accounts')
        .select()
        .eq('user_id', userId);
        // .order('account_name', ascending: true); // Optional ordering

    return response.map((data) => FinancialAccount.fromMap(data)).toList();
  }

  // --- Combined Operations with Basic Sync Logic ---

  Future<FinancialAccount> addFinancialAccount(FinancialAccount account) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated.");

    FinancialAccount remoteAccount;
    try {
      FinancialAccount accountToRemote = account.copyWith(userId: userId);
      if (accountToRemote.supabaseId == null) {
          accountToRemote = accountToRemote.copyWith(supabaseId: _uuid.v4());
      }
      remoteAccount = await addFinancialAccountRemote(accountToRemote);
    } catch (e) {
      print("Error adding financial account to remote: $e");
      rethrow;
    }
    await saveFinancialAccountLocal(remoteAccount);
    return remoteAccount;
  }

  Future<FinancialAccount> updateFinancialAccount(FinancialAccount account) async {
    final userId = _currentUserId;
    if (userId == null || account.supabaseId == null) {
      throw Exception("User not authenticated or Supabase ID missing for update.");
    }
     if (account.userId != userId) throw Exception("Cannot update account not belonging to current user.");


    FinancialAccount updatedRemoteAccount;
    try {
      updatedRemoteAccount = await updateFinancialAccountRemote(account);
    } catch (e) {
      print("Error updating financial account on remote: $e");
      rethrow;
    }
    await saveFinancialAccountLocal(updatedRemoteAccount);
    return updatedRemoteAccount;
  }

  /// Archives/Restores a financial account by toggling its 'isArchived' status.
  Future<FinancialAccount> toggleArchiveFinancialAccount(FinancialAccount account) async {
    final updatedAccount = account.copyWith(isArchived: !account.isArchived, updatedAt: DateTime.now());
    // This is an update operation.
    return await updateFinancialAccount(updatedAccount);
  }


  Future<void> deleteFinancialAccount(String supabaseId, Id isarId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated.");

    try {
      await deleteFinancialAccountRemote(supabaseId);
    } catch (e) {
      print("Error deleting financial account from remote: $e");
      rethrow;
    }
    await deleteFinancialAccountLocal(isarId);
  }

  Future<void> syncRemoteToLocal() async {
    final userId = _currentUserId;
    if (userId == null) return;

    print("Syncing financial accounts from remote to local...");
    final remoteAccounts = await fetchFinancialAccountsRemote();

    await _isar.writeTxn(() async {
      final localUserAccounts = await _isar.financialAccounts.where().userIdEqualTo(userId).findAll();
      final List<Id> idsToDelete = localUserAccounts.map((acc) => acc.isarId).toList();
      if (idsToDelete.isNotEmpty) {
        await _isar.financialAccounts.deleteAll(idsToDelete);
      }
      if (remoteAccounts.isNotEmpty) {
        await _isar.financialAccounts.putAll(remoteAccounts);
      }
    });
    print("Sync complete. Found ${remoteAccounts.length} financial accounts on remote.");
  }
}
