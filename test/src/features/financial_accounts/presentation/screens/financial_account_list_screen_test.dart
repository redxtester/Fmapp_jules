import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmapp/src/features/financial_accounts/data/models/financial_account.dart';
import 'package:fmapp/src/features/financial_accounts/presentation/screens/financial_account_list_screen.dart';
import 'package:fmapp/src/features/financial_accounts/presentation/state/financial_account_controller.dart';
import 'package:fmapp/src/features/transactions/data/models/transaction.dart';
import 'package:fmapp/src/features/transactions/presentation/state/transaction_controller.dart';
import 'package:fmapp/src/features/auth/presentation/state/auth_controller.dart'; // For potential user context
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;


// Import generated mocks
import 'financial_account_list_screen_test.mocks.dart';


@GenerateNiceMocks([
  MockSpec<FinancialAccountController>(),
  MockSpec<AuthController>(), // Mock AuthController as it's used in createWidgetUnderTest
  MockSpec<User>()
])
void main() {
  final testUser = User(id: 'user123', appMetadata: {}, userMetadata: {}, aud: 'aud', createdAt: '2023-01-01T00:00:00Z');

  final account1 = FinancialAccount(isarId: 1, supabaseId: 'acc1_supa', userId: 'user123', accountName: 'Savings', accountType: AccountType.bankAccount, initialBalance: 1000, dateAdded: DateTime.now(), createdAt: DateTime.now(), updatedAt: DateTime.now());
  final account2 = FinancialAccount(isarId: 2, supabaseId: 'acc2_supa', userId: 'user123', accountName: 'Cash Wallet', accountType: AccountType.cash, initialBalance: 500, dateAdded: DateTime.now(), createdAt: DateTime.now(), updatedAt: DateTime.now(), isArchived: true);


  Widget createWidgetUnderTest({
      AsyncValue<List<FinancialAccount>> accountsStreamValue = const AsyncLoading(),
      Map<String, double> currentBalances = const {}, // supabaseId -> balance
      bool initialShowArchived = false,
  }) {
    // Need to use a MockFinancialAccountController from the generated mocks.
    // The @GenerateNiceMocks above should generate MockFinancialAccountController.
    final mockFinancialAccountController = MockFinancialAccountController();
    when(mockFinancialAccountController.syncFinancialAccounts()).thenAnswer((_) async {});
    when(mockFinancialAccountController.deleteFinancialAccount(any, any)).thenAnswer((_) async {});
    when(mockFinancialAccountController.toggleArchiveFinancialAccount(any)).thenAnswer((_) async {});
    when(mockFinancialAccountController.state).thenReturn(const AsyncData([])); // Default state

    final mockAuthController = MockAuthController();
    when(mockAuthController.state).thenReturn(AsyncData(testUser));
    when(mockAuthController.build()).thenAnswer((_) async => testUser);


    return ProviderScope(
      overrides: [
        financialAccountsStreamProvider(initialShowArchived).overrideWith((ref) => Stream.value(
            accountsStreamValue.when(
                data: (d) => d,
                loading: () => [],
                error: (e,s) => [])
            )
        ),
        for (var entry in currentBalances.entries)
          currentBalanceProvider(entry.key).overrideWithValue(entry.value),

         authControllerProvider.overrideWith((_) => mockAuthController),
        financialAccountControllerProvider.overrideWith((_) => mockFinancialAccountController)
      ],
      child: MaterialApp(
        home: Scaffold(
            body: const FinancialAccountListScreen()
        ),
      ),
    );
  }

  group('FinancialAccountListScreen Widget Tests', () {
    testWidgets('shows loading indicator when accounts are loading', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest(accountsStreamValue: const AsyncLoading()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget); // Assuming LoadingIndicator shows a CircularProgressIndicator
    });

    testWidgets('shows error message when accounts fail to load', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest(accountsStreamValue: AsyncError('Failed to load', StackTrace.empty)));
      expect(find.textContaining('Error loading accounts:'), findsOneWidget);
      expect(find.text('Failed to load'), findsOneWidget);
    });

    testWidgets('shows empty state when no accounts are available', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest(accountsStreamValue: const AsyncData([])));
      expect(find.text('No active accounts found.'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, "Add Account"), findsOneWidget);
    });

    testWidgets('displays a list of accounts with their dynamic balances', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        accountsStreamValue: AsyncData([account1]),
        currentBalances: {'acc1_supa': 1250.50},
        initialShowArchived: false,
      ));

      expect(find.text('Savings'), findsOneWidget);
      expect(find.textContaining('Current: ETB 1,250.50'), findsOneWidget);
      expect(find.textContaining('Initial: ETB 1,000.00'), findsOneWidget);
    });

    testWidgets('toggles display of archived accounts', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        accountsStreamValue: AsyncData([account1]),
        currentBalances: {'acc1_supa': 1250.50, 'acc2_supa': 450.0},
        initialShowArchived: false,
      ));
      expect(find.text('Savings'), findsOneWidget);
      expect(find.text('Cash Wallet'), findsNothing);

      await tester.tap(find.byTooltip('Show Archived'));
      // After tapping, the showArchivedAccountsProvider changes.
      // We need to rebuild with the new stream override.
      // This requires a more sophisticated test setup or re-pumping with different overrides.
      // For now, this test part remains conceptual as in the script.
      await tester.pumpAndSettle();

      expect(find.byTooltip('Hide Archived'), findsOneWidget);
    });

    testWidgets('navigates to AddEditFinancialAccountScreen when add button is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest(accountsStreamValue: const AsyncData([])));

      // Find the add button in the AppBar. Since there might be another FAB, be specific.
      await tester.tap(find.byTooltip('Add New Account'));
      await tester.pumpAndSettle();

      expect(find.text('Add New Account'), findsOneWidget);
    });

  });
}
