import 'dart:async';
import 'package:fmapp/src/features/sim_cards/data/models/sim_card.dart';
import 'package:fmapp/src/features/sim_cards/data/repositories/sim_card_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart'; // For Id type

// Provider for SimCardController
final simCardControllerProvider = AsyncNotifierProvider<SimCardController, List<SimCard>>(() {
  return SimCardController();
});

// Provider to watch a stream of SIM cards (local first, then potentially synced)
// This directly uses the repository's local watch stream.
final simCardsStreamProvider = StreamProvider<List<SimCard>>((ref) {
  final repository = ref.watch(simCardRepositoryProvider);
  return repository.watchSimCardsLocal();
});


class SimCardController extends AsyncNotifier<List<SimCard>> {
  late SimCardRepository _repository;

  @override
  Future<List<SimCard>> build() async {
    _repository = ref.watch(simCardRepositoryProvider);
    // Initial load from local cache.
    // The UI can also use simCardsStreamProvider for reactive updates from local DB.
    // This build method can also trigger an initial sync if desired.
    // await _repository.syncRemoteToLocal(); // Optional: sync on first load
    return _repository.getSimCardsLocal();
  }

  Future<void> addSimCard(SimCard simCard) async {
    state = const AsyncLoading(); // Indicate loading state
    try {
      await _repository.addSimCard(simCard);
      // After adding, refresh the list or rely on the stream to update.
      // For non-stream state, manual refresh:
      // final updatedList = await _repository.getSimCardsLocal();
      // state = AsyncData(updatedList);
      // If relying on stream from simCardsStreamProvider, this controller's state
      // might not need to hold the list itself, or it could also listen to the stream.
      // For simplicity, this controller will manage a snapshot list.
      // The stream provider handles the reactive UI updates.
      // Let's make this controller also refresh its state after action.
       await refreshSimCards();
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace);
      rethrow; // Allow UI to catch and display specific error
    }
  }

  Future<void> updateSimCard(SimCard simCard) async {
    state = const AsyncLoading();
    try {
      await _repository.updateSimCard(simCard);
      await refreshSimCards();
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteSimCard(String supabaseId, Id isarId) async {
    state = const AsyncLoading();
    try {
      await _repository.deleteSimCard(supabaseId, isarId);
      await refreshSimCards();
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace);
      rethrow;
    }
  }

  Future<void> syncSimCards() async {
    state = const AsyncLoading();
    try {
      await _repository.syncRemoteToLocal();
      // After sync, the local stream (simCardsStreamProvider) will update automatically.
      // This controller's state (if it holds a list) should also be refreshed.
      await refreshSimCards();
       print("SimCardController: Sync complete, state refreshed.");
    } catch (e, stackTrace) {
      print("SimCardController: Sync error: $e");
      state = AsyncError(e, stackTrace);
      rethrow;
    }
  }

  // Helper to refresh the list state
  Future<void> refreshSimCards() async {
    try {
      final currentSims = await _repository.getSimCardsLocal();
      state = AsyncData(currentSims);
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace);
    }
  }
}
