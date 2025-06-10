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

// Import generated mocks (will share with login_screen_test.mocks.dart if in same dir,
// or generate its own if @GenerateNiceMocks is here too)
import 'login_screen_test.mocks.dart'; // Re-using mocks from login test for AuthController


@GenerateNiceMocks([MockSpec<AuthController>()]) // Keep it here for clarity if tests are run separately
void main() {
  late MockAuthController mockAuthController;

  setUp(() {
    mockAuthController = MockAuthController();
    when(mockAuthController.build()).thenAnswer((_) async => null);
    when(mockAuthController.state).thenReturn(const AsyncData<User?>(null));
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((_) => mockAuthController),
      ],
      child: const MaterialApp(
        home: RegistrationScreen(),
        routes: { // For navigation test
          '/login': (context) => const LoginScreen(),
        },
      ),
    );
  }

  group('RegistrationScreen Widget Tests', () {
    testWidgets('renders correctly with all UI elements', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.widgetWithText(AppBar, 'Register for fmapp'), findsOneWidget);
      expect(find.byType(CustomTextFormField), findsNWidgets(3)); // Email, Password, Confirm Password
      expect(find.widgetWithText(CustomTextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(CustomTextFormField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(CustomTextFormField, 'Confirm Password'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Register'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Already have an account? Login'), findsOneWidget);
    });

    testWidgets('shows error messages for empty fields on registration attempt', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pump();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
      expect(find.text('Please confirm your password'), findsOneWidget);
    });

    testWidgets('shows error message for password less than 6 characters', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.enterText(find.widgetWithText(CustomTextFormField, 'Email'), 'test@example.com');
      await tester.enterText(find.widgetWithText(CustomTextFormField, 'Password'), '123');
      await tester.enterText(find.widgetWithText(CustomTextFormField, 'Confirm Password'), '123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pump();
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('shows error message for mismatched passwords', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.enterText(find.widgetWithText(CustomTextFormField, 'Email'), 'test@example.com');
      await tester.enterText(find.widgetWithText(CustomTextFormField, 'Password'), 'password123');
      await tester.enterText(find.widgetWithText(CustomTextFormField, 'Confirm Password'), 'password456');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pump();
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('calls AuthController.signUp on valid form submission', (WidgetTester tester) async {
      when(mockAuthController.signUp(any, any)).thenAnswer((_) async {});
      when(mockAuthController.state).thenReturn(const AsyncData<User?>(null));

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(find.widgetWithText(CustomTextFormField, 'Email'), 'test@example.com');
      await tester.enterText(find.widgetWithText(CustomTextFormField, 'Password'), 'password123');
      await tester.enterText(find.widgetWithText(CustomTextFormField, 'Confirm Password'), 'password123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      // Simulate loading state
      // when(mockAuthController.state).thenReturn(const AsyncLoading<User?>()..copyWithPrevious(const AsyncData<User?>(null)));
      // await tester.pump();

      verify(mockAuthController.signUp('test@example.com', 'password123')).called(1);
    });

    testWidgets('shows SnackBar on registration success and navigates', (WidgetTester tester) async {
      when(mockAuthController.signUp(any, any)).thenAnswer((_) async {
        // Simulate successful registration, no error thrown
      });
      when(mockAuthController.state).thenReturn(const AsyncData<User?>(null));


      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(find.widgetWithText(CustomTextFormField, 'Email'), 'test@example.com');
      await tester.enterText(find.widgetWithText(CustomTextFormField, 'Password'), 'password123');
      await tester.enterText(find.widgetWithText(CustomTextFormField, 'Confirm Password'), 'password123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pumpAndSettle(); // Process SnackBar & navigation

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Registration successful! Please check your email for verification if enabled.'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget); // Navigates to LoginScreen
      expect(find.byType(RegistrationScreen), findsNothing);
    });


    testWidgets('navigates to LoginScreen when "Login" button is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.widgetWithText(TextButton, 'Already have an account? Login'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(RegistrationScreen), findsNothing);
    });
  });
}
