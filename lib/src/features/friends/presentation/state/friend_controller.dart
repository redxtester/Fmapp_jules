import 'dart:async';
import 'package:fmapp/src/features/friends/data/models/friend.dart';
import 'package:fmapp/src/features/friends/data/repositories/friend_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart'; // For Id type

// Provider for FriendController
final friendControllerProvider =
    AsyncNotifierProvider<FriendController, List<Friend>>(() {
  return FriendController();
});

// Stream provider for friends
final friendsStreamProvider = StreamProvider.autoDispose<List<Friend>>((ref) {
  final repository = ref.watch(friendRepositoryProvider);
  return repository.watchFriendsLocal();
});


class FriendController extends AsyncNotifier<List<Friend>> {
  late FriendRepository _repository;

  @override
  Future<List<Friend>> build() async {
    _repository = ref.watch(friendRepositoryProvider);
    // Optional: Trigger an initial sync
    // Future.microtask(() => syncFriends()); // Non-blocking
    return _repository.getFriendsLocal();
  }

  Future<void> addFriend(Friend friend) async {
    state = const AsyncLoading<List<Friend>>().copyWithPrevious(state);
    try {
      await _repository.addFriend(friend);
      await _refreshState();
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace).copyWithPrevious(state);
      rethrow;
    }
  }

  Future<void> updateFriend(Friend friend) async {
    state = const AsyncLoading<List<Friend>>().copyWithPrevious(state);
    try {
      await _repository.updateFriend(friend);
      await _refreshState();
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace).copyWithPrevious(state);
      rethrow;
    }
  }

  Future<void> deleteFriend(String supabaseId, Id isarId) async {
    state = const AsyncLoading<List<Friend>>().copyWithPrevious(state);
    try {
      await _repository.deleteFriend(supabaseId, isarId);
      await _refreshState();
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace).copyWithPrevious(state);
      rethrow;
    }
  }

  Future<void> syncFriends() async {
    state = const AsyncLoading<List<Friend>>().copyWithPrevious(state);
    try {
      await _repository.syncRemoteToLocal();
      await _refreshState(); // Stream provider will also update UI
      print("FriendController: Sync complete, state refreshed.");
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace).copyWithPrevious(state);
      rethrow;
    }
  }

  Future<void> _refreshState() async {
    try {
      final currentFriends = await _repository.getFriendsLocal();
      state = AsyncData(currentFriends);
    } catch (e, stackTrace) {
      // If the previous state had data, keep it while showing error
      state = AsyncError(e, stackTrace).copyWithPrevious(state);
    }
  }
}
