import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmapp/src/core/presentation/widgets/custom_text_form_field.dart';
import 'package:fmapp/src/features/auth/presentation/screens/login_screen.dart';
import 'package:fmapp/src/features/auth/presentation/screens/registration_screen.dart';
import 'package:fmapp/src/features/auth/presentation/state/auth_controller.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

// Import generated mocks
import 'login_screen_test.mocks.dart';

// Mock AuthController. Since AuthController is an AsyncNotifier,
// mocking its behavior for UI tests can be done by mocking the notifier itself.
// We also need a User mock if we test authenticated states.
@GenerateNiceMocks([
  MockSpec<AuthController>(),
  MockSpec<User>()
])
void main() {
  late MockAuthController mockAuthController;

  setUp(() {
    mockAuthController = MockAuthController();
    // Default stub for the state, can be overridden in tests
    when(mockAuthController.build()).thenAnswer((_) async => null); // Initial state, no user
    // Stub the state property of the notifier to return AsyncData(null) by default
    // This simulates the AsyncNotifier's state.
    when(mockAuthController.state).thenReturn(const AsyncData<User?>(null));

  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        // Override the authControllerProvider to return our mock controller's state
        // and the notifier to return the mock controller itself.
        authControllerProvider.overrideWith((_) => mockAuthController),
      ],
      child: const MaterialApp(
        home: LoginScreen(),
        // Need RegistrationScreen for navigation test
        routes: {
          '/register': (context) => const RegistrationScreen(),
        },
      ),
    );
  }

  group('LoginScreen Widget Tests', () {
    testWidgets('renders correctly with all UI elements', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.widgetWithText(AppBar, 'Login to fmapp'), findsOneWidget);
      expect(find.byType(CustomTextFormField), findsNWidgets(2)); // Email and Password
      expect(find.widgetWithText(CustomTextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(CustomTextFormField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Don\'t have an account? Register'), findsOneWidget);
    });

    testWidgets('shows error messages for empty email and password fields on login attempt', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump(); // Rebuild widget after validation

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('shows error message for invalid email format', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(find.widgetWithText(CustomTextFormField, 'Email'), 'invalidemail');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('calls AuthController.signInWithPassword on valid form submission', (WidgetTester tester) async {
      // Stub the signInWithPassword method to complete successfully
      when(mockAuthController.signInWithPassword(any, any)).thenAnswer((_) async {});
      // Ensure state remains AsyncData(null) or some other non-loading state initially
      when(mockAuthController.state).thenReturn(const AsyncData<User?>(null));


      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(find.widgetWithText(CustomTextFormField, 'Email'), 'test@example.com');
      await tester.enterText(find.widgetWithText(CustomTextFormField, 'Password'), 'password123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      // The UI might show a loading indicator if the state changes to AsyncLoading
      // For this, we need to update the mock's state when signInWithPassword is called.

      // Simulate loading state
      when(mockAuthController.state).thenReturn(const AsyncLoading<User?>()..copyWithPrevious(const AsyncData<User?>(null)));
      await tester.pump(); // Show loading

      // Simulate success state (navigation will be handled by AuthGate based on actual state change)
      // For this test, we just verify the call.
      // when(mockAuthController.state).thenReturn(AsyncData<User?>(MockUser()));
      // await tester.pump();


      verify(mockAuthController.signInWithPassword('test@example.com', 'password123')).called(1);
    });

    testWidgets('shows loading indicator when auth state is loading', (WidgetTester tester) async {
      when(mockAuthController.state).thenReturn(const AsyncLoading<User?>()..copyWithPrevious(const AsyncData<User?>(null)));

      await tester.pumpWidget(createWidgetUnderTest());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The button might be disabled or replaced by the indicator
      expect(find.widgetWithText(ElevatedButton, 'Login'), findsNothing);
    });

    testWidgets('shows SnackBar on login failure', (WidgetTester tester) async {
      final exception = Exception('Login Failed: Invalid credentials');
      when(mockAuthController.signInWithPassword(any, any)).thenThrow(exception);
      when(mockAuthController.state).thenReturn(const AsyncData<User?>(null)); // Start not loading

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(find.widgetWithText(CustomTextFormField, 'Email'), 'test@example.com');
      await tester.enterText(find.widgetWithText(CustomTextFormField, 'Password'), 'wrongpassword');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));

      // Simulate error state after the call
      // In a real scenario, the controller would update its state to AsyncError.
      // Here, we need to trigger a pump after the async call could have completed.
      await tester.pumpAndSettle(); // process SnackBar

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Login Failed: Invalid credentials'), findsOneWidget);
    });

    testWidgets('navigates to RegistrationScreen when "Register" button is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.widgetWithText(TextButton, 'Don\'t have an account? Register'));
      await tester.pumpAndSettle(); // Wait for navigation to complete

      expect(find.byType(RegistrationScreen), findsOneWidget);
      // Ensure we've left the LoginScreen (or it's not the primary anymore)
      expect(find.byType(LoginScreen), findsNothing);
    });
  });
}
