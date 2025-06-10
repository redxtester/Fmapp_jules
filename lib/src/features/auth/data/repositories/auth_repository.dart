import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Future<void> signUp({required String email, required String password}) async {
    try {
      await _client.auth.signUp(email: email, password: password);
    } on AuthException catch (e) {
      // Consider creating custom exceptions or a more robust error handling
      throw Exception('Failed to sign up: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred during sign up: ${e.toString()}');
    }
  }

  Future<void> signInWithPassword({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw Exception('Failed to sign in: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred during sign in: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw Exception('Failed to sign out: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred during sign out: ${e.toString()}');
    }
  }

  // TODO: Implement other methods as needed (e.g., password reset, update user)
}
