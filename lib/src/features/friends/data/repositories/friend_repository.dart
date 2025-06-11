import 'package:fmapp/src/core/data/isar_service.dart';
import 'package:fmapp/src/features/friends/data/models/friend.dart';
import 'package:fmapp/main.dart' show supabaseClientProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// Provider for FriendRepository
final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  final isar = ref.watch(isarInstanceProvider);
  final supabaseClient = ref.watch(supabaseClientProvider);
  return FriendRepository(isar, supabaseClient, const Uuid());
});

class FriendRepository {
  final Isar _isar;
  final SupabaseClient _supabase;
  final Uuid _uuid;

  FriendRepository(this._isar, this._supabase, this._uuid);

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // --- Local Isar Operations ---

  Stream<List<Friend>> watchFriendsLocal() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);
    return _isar.friends.where().userIdEqualTo(userId).sortByName().watch(fireImmediately: true);
  }

  Future<List<Friend>> getFriendsLocal() async {
    final userId = _currentUserId;
    if (userId == null) return [];
    return _isar.friends.where().userIdEqualTo(userId).sortByName().findAll();
  }

  Future<Friend?> getFriendBySupabaseIdLocal(String supabaseId) async {
    return _isar.friends.filter().supabaseIdEqualTo(supabaseId).findFirst();
  }

  Future<Id> saveFriendLocal(Friend friend) async {
    return await _isar.writeTxn(() async {
      return await _isar.friends.put(friend);
    });
  }

  Future<bool> deleteFriendLocal(Id isarId) async {
    // PRD doesn't specify cascading delete for loans if a friend is deleted.
    // Loans table has associatedFriendId. If friend is deleted, that link breaks.
    // This might need to be handled by preventing friend deletion if active loans exist.
    // For P0, direct deletion.
    return await _isar.writeTxn(() async {
      return await _isar.friends.delete(isarId);
    });
  }

  // --- Supabase Operations ---

  Future<Friend> addFriendRemote(Friend friend) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated to add friend remotely.");

    final friendWithSupabaseId = friend.supabaseId == null
        ? friend.copyWith(supabaseId: _uuid.v4(), userId: userId)
        : friend.copyWith(userId: userId);

    final response = await _supabase
        .from('friends')
        .insert(friendWithSupabaseId.toMap())
        .select()
        .single();

    return Friend.fromMap(response);
  }

  Future<Friend> updateFriendRemote(Friend friend) async {
    if (friend.supabaseId == null) throw Exception("Supabase ID is required to update friend remotely.");
    final userId = _currentUserId;
    if (userId == null || friend.userId != userId) throw Exception("User cannot update this friend record.");

    final response = await _supabase
        .from('friends')
        .update(friend.toMap()..remove('id')..remove('user_id')..remove('created_at'))
        .eq('id', friend.supabaseId!)
        .eq('user_id', userId)
        .select()
        .single();

    return Friend.fromMap(response);
  }

  Future<void> deleteFriendRemote(String supabaseId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated to delete friend remotely.");
    // See note on deleteFriendLocal regarding loans. Supabase FK constraints might prevent this.
    // The `loan_debts` table would need `ON DELETE SET NULL` or `ON DELETE RESTRICT` for `associatedFriendId`.
    // Let's assume `ON DELETE RESTRICT` is default or desired. If so, this call will fail if loans exist.
    await _supabase
        .from('friends')
        .delete()
        .eq('id', supabaseId)
        .eq('user_id', userId);
  }

  Future<List<Friend>> fetchFriendsRemote() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    final response = await _supabase
        .from('friends')
        .select()
        .eq('user_id', userId)
        .order('friend_name', ascending: true);

    return response.map((data) => Friend.fromMap(data)).toList();
  }

  // --- Combined Operations with Basic Sync Logic ---

  Future<Friend> addFriend(Friend friend) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated.");

    Friend remoteFriend;
    try {
      Friend friendToRemote = friend.copyWith(userId: userId);
      if (friendToRemote.supabaseId == null) {
          friendToRemote = friendToRemote.copyWith(supabaseId: _uuid.v4());
      }
      remoteFriend = await addFriendRemote(friendToRemote);
    } catch (e) {
      print("Error adding friend to remote: $e");
      rethrow;
    }
    await saveFriendLocal(remoteFriend);
    return remoteFriend;
  }

  Future<Friend> updateFriend(Friend friend) async {
    final userId = _currentUserId;
    if (userId == null || friend.supabaseId == null) {
      throw Exception("User not authenticated or Supabase ID missing for update.");
    }
    if (friend.userId != userId) throw Exception("Cannot update friend not belonging to current user.");

    Friend updatedRemoteFriend;
    try {
      updatedRemoteFriend = await updateFriendRemote(friend);
    } catch (e) {
      print("Error updating friend on remote: $e");
      rethrow;
    }
    await saveFriendLocal(updatedRemoteFriend);
    return updatedRemoteFriend;
  }

  Future<void> deleteFriend(String supabaseId, Id isarId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated.");

    try {
      await deleteFriendRemote(supabaseId);
    } catch (e) {
      print("Error deleting friend from remote: $e");
      // App should handle this, e.g. if friend has active loans.
      rethrow;
    }
    await deleteFriendLocal(isarId);
  }

  Future<void> syncRemoteToLocal() async {
    final userId = _currentUserId;
    if (userId == null) return;

    print("Syncing friends from remote to local...");
    final remoteFriends = await fetchFriendsRemote();

    await _isar.writeTxn(() async {
      final localUserFriends = await _isar.friends.where().userIdEqualTo(userId).findAll();
      final List<Id> idsToDelete = localUserFriends.map((f) => f.isarId).toList();
      if (idsToDelete.isNotEmpty) {
        await _isar.friends.deleteAll(idsToDelete);
      }
      if (remoteFriends.isNotEmpty) {
        await _isar.friends.putAll(remoteFriends);
      }
    });
    print("Sync complete. Found ${remoteFriends.length} friends on remote.");
  }
}

extension QueryBuilderSortByFriendName<T, R, S> on QueryBuilder<T, R, S> {
    QueryBuilder<T, R, QAfterSortBy> sortByName() {
        return QueryBuilder.apply(this, (query) {
        return query.sortBy(r'friendName');
        });
    }

    QueryBuilder<T, R, QAfterSortBy> sortByNameDesc() {
        return QueryBuilder.apply(this, (query) {
        return query.sortByDesc(r'friendName');
        });
    }
}
