import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent, Session, User; // Specific imports
import 'package:fmapp/src/features/auth/data/repositories/auth_repository.dart';

// Provider for AuthController
// Using riverpod_generator style for autoDispose and family if needed later
// For now, a simple AsyncNotifierProvider
final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(() {
  return AuthController();
});

class AuthController extends AsyncNotifier<User?> {
  late final AuthRepository _authRepository;
  StreamSubscription<AuthState>? _authStateSubscription;

  @override
  Future<User?> build() async {
    _authRepository = ref.watch(authRepositoryProvider);

    // Listen to auth state changes and update the state accordingly
    _authStateSubscription = _authRepository.authStateChanges.listen((event) {
      // The event itself contains session, user, etc.
      // We are interested in the user object from the current session or event.
      state = AsyncData(_authRepository.currentUser);
    });

    // Dispose the subscription when the notifier is disposed
    ref.onDispose(() {
      _authStateSubscription?.cancel();
    });

    // Return the initial user state
    return _authRepository.currentUser;
  }

  Future<void> signUp(String email, String password) async {
    state = const AsyncLoading();
    try {
      await _authRepository.signUp(email: email, password: password);
      // Supabase onAuthStateChange will trigger state update if successful
      // Or, if using email confirmation, user remains in current state until confirmed.
      // For this basic setup, we assume direct login or rely on stream.
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow; // Allow UI to catch and display error
    }
  }

  Future<void> signInWithPassword(String email, String password) async {
    state = const AsyncLoading();
    try {
      await _authRepository.signInWithPassword(email: email, password: password);
      // onAuthStateChange will trigger state update
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await _authRepository.signOut();
      // onAuthStateChange will trigger state update
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      // No need to rethrow here as signout failure might not need specific UI reaction beyond error message
    }
  }
}
