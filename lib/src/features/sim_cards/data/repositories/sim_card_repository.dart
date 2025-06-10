import 'package:fmapp/src/core/data/isar_service.dart';
import 'package:fmapp/src/features/auth/presentation/state/auth_controller.dart'; // To get current user ID
import 'package:fmapp/src/features/sim_cards/data/models/sim_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart'; // For generating client-side UUIDs for Supabase ID

// Provider for SimCardRepository
final simCardRepositoryProvider = Provider<SimCardRepository>((ref) {
  final isar = ref.watch(isarInstanceProvider);
  final supabaseClient = ref.watch(supabaseClientProvider); // Assuming supabaseClientProvider is defined (from main.dart)
  final userRepository = ref.watch(authControllerProvider.notifier); // To get user ID, though direct user ID access might be better
  // A better way to get user ID would be from a dedicated user provider or auth state.
  // For now, this is a placeholder way to access it, assuming AuthController exposes it or can get it.
  // final userId = Supabase.instance.client.auth.currentUser?.id;
  // It's better if the calling layer (Controller) provides the userId to repository methods.
  return SimCardRepository(isar, supabaseClient, const Uuid());
});

class SimCardRepository {
  final Isar _isar;
  final SupabaseClient _supabase;
  final Uuid _uuid;

  SimCardRepository(this._isar, this._supabase, this._uuid);

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // --- Local Isar Operations ---

  Stream<List<SimCard>> watchSimCardsLocal() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);
    return _isar.simCards.where().userIdEqualTo(userId).watch(fireImmediately: true);
  }

  Future<List<SimCard>> getSimCardsLocal() async {
    final userId = _currentUserId;
    if (userId == null) return [];
    return _isar.simCards.where().userIdEqualTo(userId).findAll();
  }

  Future<SimCard?> getSimCardBySupabaseIdLocal(String supabaseId) async {
    return _isar.simCards.filter().supabaseIdEqualTo(supabaseId).findFirst();
  }

  Future<Id> saveSimCardLocal(SimCard simCard) async {
    return await _isar.writeTxn(() async {
      return await _isar.simCards.put(simCard);
    });
  }

  Future<bool> deleteSimCardLocal(Id isarId) async {
    return await _isar.writeTxn(() async {
      return await _isar.simCards.delete(isarId);
    });
  }

  // --- Supabase Operations ---

  Future<SimCard> addSimCardRemote(SimCard simCard) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated to add SIM card remotely.");

    // Ensure supabaseId is generated if not present (client-side generation for now)
    final simCardWithSupabaseId = simCard.supabaseId == null
        ? simCard.copyWith(supabaseId: _uuid.v4(), userId: userId)
        : simCard.copyWith(userId: userId);

    final response = await _supabase
        .from('sim_cards')
        .insert(simCardWithSupabaseId.toMap())
        .select() // Fetch the inserted row to get DB-generated fields like created_at
        .single(); // Expect a single row back

    return SimCard.fromMap(response);
  }

  Future<SimCard> updateSimCardRemote(SimCard simCard) async {
    if (simCard.supabaseId == null) throw Exception("Supabase ID is required to update SIM card remotely.");
    final userId = _currentUserId;
    if (userId == null || simCard.userId != userId) throw Exception("User cannot update this SIM card.");

    final response = await _supabase
        .from('sim_cards')
        .update(simCard.toMap()..remove('id')..remove('user_id')..remove('created_at')) // Don't update PK, FK, or created_at via client
        .eq('id', simCard.supabaseId!)
        .eq('user_id', userId) // Ensure user owns the record
        .select()
        .single();

    return SimCard.fromMap(response);
  }

  Future<void> deleteSimCardRemote(String supabaseId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated to delete SIM card remotely.");

    await _supabase
        .from('sim_cards')
        .delete()
        .eq('id', supabaseId)
        .eq('user_id', userId); // Ensure user owns the record
  }

  Future<List<SimCard>> fetchSimCardsRemote() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    final response = await _supabase
        .from('sim_cards')
        .select()
        .eq('user_id', userId);
        // .order('created_at', ascending: false); // Optional ordering

    return response.map((data) => SimCard.fromMap(data)).toList();
  }

  // --- Combined Operations with Basic Sync Logic ---

  Future<SimCard> addSimCard(SimCard simCard) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated.");

    // Add to remote first to get supabaseId and ensure server acknowledges
    SimCard remoteSimCard;
    try {
      // Ensure userId is set correctly before sending to remote
      SimCard cardToRemote = simCard.copyWith(userId: userId);
      if (cardToRemote.supabaseId == null) { // Generate ID if it's a new card without one
          cardToRemote = cardToRemote.copyWith(supabaseId: _uuid.v4());
      }
      remoteSimCard = await addSimCardRemote(cardToRemote);
    } catch (e) {
      // Handle remote error (e.g., network issue, Supabase error)
      // For now, rethrow. Could implement retry or queueing later.
      print("Error adding SIM card to remote: $e");
      rethrow;
    }

    // Save/update in local Isar using data from remote (has DB timestamps)
    // This ensures local copy is consistent with remote after add.
    await saveSimCardLocal(remoteSimCard);
    return remoteSimCard;
  }

  Future<SimCard> updateSimCard(SimCard simCard) async {
    final userId = _currentUserId;
    if (userId == null || simCard.supabaseId == null) {
      throw Exception("User not authenticated or Supabase ID missing for update.");
    }
    if (simCard.userId != userId) throw Exception("Cannot update SIM card not belonging to current user.");

    SimCard updatedRemoteSimCard;
    try {
      updatedRemoteSimCard = await updateSimCardRemote(simCard);
    } catch (e) {
      print("Error updating SIM card on remote: $e");
      rethrow;
    }

    // Update local Isar with the version from remote
    await saveSimCardLocal(updatedRemoteSimCard); // `put` will update based on IsarId
    return updatedRemoteSimCard;
  }

  Future<void> deleteSimCard(String supabaseId, Id isarId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("User not authenticated.");

    try {
      await deleteSimCardRemote(supabaseId);
    } catch (e) {
      print("Error deleting SIM card from remote: $e");
      // Decide if we should still delete locally or handle error.
      // For now, if remote fails, we might not want to delete locally to allow retry.
      rethrow;
    }

    await deleteSimCardLocal(isarId);
  }

  /// Syncs SIM cards from Supabase to local Isar.
  /// This is a basic sync: fetches all remote and replaces local for the user.
  Future<void> syncRemoteToLocal() async {
    final userId = _currentUserId;
    if (userId == null) return;

    print("Syncing SIM cards from remote to local...");
    final remoteSimCards = await fetchSimCardsRemote();

    await _isar.writeTxn(() async {
      // Clear existing local SIM cards for this user first? Or perform a diff?
      // For simplicity now, clear and replace. More advanced sync would diff.
      final localUserSims = await _isar.simCards.where().userIdEqualTo(userId).findAll();
      final List<Id> idsToDelete = localUserSims.map((s) => s.isarId).toList();
      if (idsToDelete.isNotEmpty) {
        await _isar.simCards.deleteAll(idsToDelete);
      }
      if (remoteSimCards.isNotEmpty) {
        await _isar.simCards.putAll(remoteSimCards);
      }
    });
    print("Sync complete. Found ${remoteSimCards.length} SIM cards on remote.");
  }
}
