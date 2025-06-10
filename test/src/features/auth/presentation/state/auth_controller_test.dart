import 'package:flutter_test/flutter_test.dart';
import 'package:fmapp/src/features/auth/data/repositories/auth_repository.dart';
import 'package:fmapp/src/features/auth/presentation/state/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User, AuthState, AuthChangeEvent, Session; // Specific imports

// Import generated mocks
import 'auth_controller_test.mocks.dart';

// Annotations to generate mock for AuthRepository
@GenerateNiceMocks([MockSpec<AuthRepository>()])
void main() {
  late MockAuthRepository mockAuthRepository;
  late ProviderContainer container;
  // Define a test user
  final testUser = User(
    id: 'test-user-id',
    appMetadata: {},
    userMetadata: {'email': 'test@example.com'},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
  );

  setUp(() {
    mockAuthRepository = MockAuthRepository();

    // Stub the authStateChanges stream and currentUser before creating the container
    when(mockAuthRepository.authStateChanges).thenAnswer((_) => Stream.empty());
    when(mockAuthRepository.currentUser).thenReturn(null); // Default to no user

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('AuthController Tests', () {
    const testEmail = 'test@example.com';
    const testPassword = 'password123';

    test('initial state is AsyncData(null) when no user is logged in', () async {
      // The build method of AuthController is async.
      // We need to wait for the initial state to settle.
      final initialState = await container.read(authControllerProvider.future);
      expect(initialState, isNull);
      expect(container.read(authControllerProvider), const AsyncData<User?>(null));
    });

    test('initial state is AsyncData(user) when a user is already logged in', () async {
      // Override mocks for this specific test
      when(mockAuthRepository.currentUser).thenReturn(testUser);
      // Recreate container with this specific override for initial state
      container.dispose(); // Dispose previous container
      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
        ],
      );

      final initialState = await container.read(authControllerProvider.future);
      expect(initialState, testUser);
      expect(container.read(authControllerProvider), AsyncData<User?>(testUser));
    });


    group('signUp', () {
      test('calls AuthRepository.signUp and state remains AsyncData on success (relies on authStateChanges)', () async {
        when(mockAuthRepository.signUp(email: testEmail, password: testPassword))
            .thenAnswer((_) async {});

        final controller = container.read(authControllerProvider.notifier);
        await controller.signUp(testEmail, testPassword);

        // Verify repository method was called
        verify(mockAuthRepository.signUp(email: testEmail, password: testPassword)).called(1);
        // State should ideally reflect the outcome via authStateChanges stream.
        // For testing the direct action, we check it doesn't immediately go to error.
        // The actual user state update comes from the stream listener in build().
        expect(container.read(authControllerProvider), isA<AsyncData>());
      });

      test('sets state to AsyncError on AuthRepository.signUp failure', () async {
        final exception = Exception('Sign up failed');
        when(mockAuthRepository.signUp(email: testEmail, password: testPassword))
            .thenThrow(exception);

        final controller = container.read(authControllerProvider.notifier);

        // Expect the signUp method to throw, so UI can catch it
        await expectLater(controller.signUp(testEmail, testPassword), throwsA(isA<Exception>()));

        // Verify state is AsyncError
        expect(container.read(authControllerProvider), isA<AsyncError>());
        expect(container.read(authControllerProvider).error, exception);
      });
    });

    group('signInWithPassword', () {
      test('calls AuthRepository.signInWithPassword and state remains AsyncData on success (relies on authStateChanges)', () async {
        when(mockAuthRepository.signInWithPassword(email: testEmail, password: testPassword))
            .thenAnswer((_) async {});

        final controller = container.read(authControllerProvider.notifier);
        await controller.signInWithPassword(testEmail, testPassword);

        verify(mockAuthRepository.signInWithPassword(email: testEmail, password: testPassword)).called(1);
        expect(container.read(authControllerProvider), isA<AsyncData>());
      });

      test('sets state to AsyncError on AuthRepository.signInWithPassword failure', () async {
        final exception = Exception('Sign in failed');
        when(mockAuthRepository.signInWithPassword(email: testEmail, password: testPassword))
            .thenThrow(exception);

        final controller = container.read(authControllerProvider.notifier);
        await expectLater(controller.signInWithPassword(testEmail, testPassword), throwsA(isA<Exception>()));

        expect(container.read(authControllerProvider), isA<AsyncError>());
        expect(container.read(authControllerProvider).error, exception);
      });
    });

    group('signOut', () {
      test('calls AuthRepository.signOut and state remains AsyncData on success (relies on authStateChanges)', () async {
        when(mockAuthRepository.signOut()).thenAnswer((_) async {});

        final controller = container.read(authControllerProvider.notifier);
        await controller.signOut();

        verify(mockAuthRepository.signOut()).called(1);
        expect(container.read(authControllerProvider), isA<AsyncData>()); // User becomes null via stream
      });

      test('sets state to AsyncError on AuthRepository.signOut failure', () async {
        final exception = Exception('Sign out failed');
        when(mockAuthRepository.signOut()).thenThrow(exception);

        final controller = container.read(authControllerProvider.notifier);
        // SignOut in controller doesn't rethrow, so we don't expectLater throws
        await controller.signOut();

        expect(container.read(authControllerProvider), isA<AsyncError>());
        expect(container.read(authControllerProvider).error, exception);
      });
    });

    test('updates state upon receiving new AuthState from repository stream', () async {
      final mockUser = User(id: 'user123', appMetadata: {}, userMetadata: {}, aud: 'aud', createdAt: DateTime.now().toIso8601String());
      final authStateStreamController = StreamController<AuthState>();

      when(mockAuthRepository.authStateChanges).thenAnswer((_) => authStateStreamController.stream);
      when(mockAuthRepository.currentUser).thenReturn(null); // Initial state

      // Re-initialize container to pick up the new stream mock
      container.dispose();
      container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(mockAuthRepository)]);

      // Wait for initial build
      await container.read(authControllerProvider.future);
      expect(container.read(authControllerProvider).value, isNull);

      // Simulate a sign-in event via the stream
      // For this, we also need to update what currentUser would return after the event
      when(mockAuthRepository.currentUser).thenReturn(mockUser);
      authStateStreamController.add(AuthState(AuthChangeEvent.signedIn, Session(
        accessToken: 'token',
        tokenType: 'bearer',
        user: mockUser
      )));

      // Allow stream to propagate and notifier to update state
      await container.pump(); // Pump container to process stream update

      // Check if state updated to the new user
      expect(container.read(authControllerProvider).value, mockUser);

      // Simulate a sign-out event
      when(mockAuthRepository.currentUser).thenReturn(null);
      authStateStreamController.add(AuthState(AuthChangeEvent.signedOut, null));
      await container.pump();
      expect(container.read(authControllerProvider).value, isNull);

      authStateStreamController.close();
    });
  });
}

extension ProviderContainerPump on ProviderContainer {
  Future<void> pump([Duration duration = const Duration(milliseconds: 0)]) {
    return Future.delayed(duration);
  }
}
