import 'package:flutter_test/flutter_test.dart';
import 'package:fmapp/src/features/auth/data/repositories/auth_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import generated mocks
import 'auth_repository_test.mocks.dart';

// Annotations to generate mocks for SupabaseClient and GoTrueClient
// To generate mocks, run: flutter pub run build_runner build --delete-conflicting-outputs
@GenerateNiceMocks([
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<SupabaseQueryBuilder>(), // Added for potential future use, not strictly needed for auth
  MockSpec<SupabaseStorageClient>(), // Added for storage if used by other parts of repo
  MockSpec<RealtimeClient>(), // Added for realtime if used
  MockSpec<FunctionsClient>(), // Added for functions if used
  MockSpec<PostgrestFilterBuilder>(), // For query building
  MockSpec<UserResponse>(),
  MockSpec<Session>(),
  MockSpec<User>(),
])
void main() {
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockGoTrueClient;
  late AuthRepository authRepository;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockGoTrueClient = MockGoTrueClient();
    // Stubbing SupabaseClient.auth to return our mockGoTrueClient
    when(mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
    authRepository = AuthRepository(mockSupabaseClient);
  });

  group('AuthRepository Tests', () {
    const testEmail = 'test@example.com';
    const testPassword = 'password123';

    group('signUp', () {
      test('completes successfully when Supabase signUp succeeds', () async {
        when(mockGoTrueClient.signUp(email: testEmail, password: testPassword))
            .thenAnswer((_) async => MockUserResponse()); // Return a mock response

        await expectLater(
            authRepository.signUp(email: testEmail, password: testPassword),
            completes);
        verify(mockGoTrueClient.signUp(email: testEmail, password: testPassword)).called(1);
      });

      test('throws an exception when Supabase signUp throws AuthException', () async {
        final authException = AuthException('Failed to sign up', statusCode: '400');
        when(mockGoTrueClient.signUp(email: testEmail, password: testPassword))
            .thenThrow(authException);

        expect(
          () => authRepository.signUp(email: testEmail, password: testPassword),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Failed to sign up: Failed to sign up'))),
        );
        verify(mockGoTrueClient.signUp(email: testEmail, password: testPassword)).called(1);
      });
       test('throws a generic exception for non-AuthException errors during signUp', () async {
        final genericException = Exception('Network error');
        when(mockGoTrueClient.signUp(email: testEmail, password: testPassword))
            .thenThrow(genericException);

        expect(
            () => authRepository.signUp(email: testEmail, password: testPassword),
            throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('An unexpected error occurred during sign up'))),
        );
      });
    });

    group('signInWithPassword', () {
      test('completes successfully when Supabase signInWithPassword succeeds', () async {
        when(mockGoTrueClient.signInWithPassword(email: testEmail, password: testPassword))
            .thenAnswer((_) async => MockUserResponse());

        await expectLater(
            authRepository.signInWithPassword(email: testEmail, password: testPassword),
            completes);
        verify(mockGoTrueClient.signInWithPassword(email: testEmail, password: testPassword)).called(1);
      });

      test('throws an exception when Supabase signInWithPassword throws AuthException', () async {
        final authException = AuthException('Invalid login credentials', statusCode: '400');
        when(mockGoTrueClient.signInWithPassword(email: testEmail, password: testPassword))
            .thenThrow(authException);

        expect(
          () => authRepository.signInWithPassword(email: testEmail, password: testPassword),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Failed to sign in: Invalid login credentials'))),
        );
      });
       test('throws a generic exception for non-AuthException errors during signInWithPassword', () async {
        final genericException = Exception('Network error');
        when(mockGoTrueClient.signInWithPassword(email: testEmail, password: testPassword))
            .thenThrow(genericException);

        expect(
            () => authRepository.signInWithPassword(email: testEmail, password: testPassword),
            throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('An unexpected error occurred during sign in'))),
        );
      });
    });

    group('signOut', () {
      test('completes successfully when Supabase signOut succeeds', () async {
        when(mockGoTrueClient.signOut()).thenAnswer((_) async {});

        await expectLater(authRepository.signOut(), completes);
        verify(mockGoTrueClient.signOut()).called(1);
      });

      test('throws an exception when Supabase signOut throws AuthException', () async {
        final authException = AuthException('Sign out failed');
        when(mockGoTrueClient.signOut()).thenThrow(authException);

        expect(
          () => authRepository.signOut(),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Failed to sign out: Sign out failed'))),
        );
      });
      test('throws a generic exception for non-AuthException errors during signOut', () async {
        final genericException = Exception('Network error');
        when(mockGoTrueClient.signOut()).thenThrow(genericException);

        expect(
            () => authRepository.signOut(),
            throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('An unexpected error occurred during sign out'))),
        );
      });
    });

    group('currentUser', () {
      test('returns user when Supabase currentUser is not null', () {
        final mockUser = MockUser();
        when(mockGoTrueClient.currentUser).thenReturn(mockUser);
        expect(authRepository.currentUser, mockUser);
      });

      test('returns null when Supabase currentUser is null', () {
        when(mockGoTrueClient.currentUser).thenReturn(null);
        expect(authRepository.currentUser, isNull);
      });
    });

    group('authStateChanges', () {
      test('correctly streams AuthState changes from GoTrueClient', () {
        // Arrange
        final mockAuthStateStream = Stream.value(AuthState(AuthChangeEvent.signedIn, MockSession()));
        when(mockGoTrueClient.onAuthStateChange).thenAnswer((_) => mockAuthStateStream);

        // Act & Assert
        expect(authRepository.authStateChanges, mockAuthStateStream);
        verify(mockGoTrueClient.onAuthStateChange).called(1);
      });
    });
  });
}
