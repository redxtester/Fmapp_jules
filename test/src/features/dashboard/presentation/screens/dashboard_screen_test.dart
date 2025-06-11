import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmapp/src/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:fmapp/src/features/financial_accounts/data/models/financial_account.dart';
import 'package:fmapp/src/features/financial_accounts/presentation/state/financial_account_controller.dart';
import 'package:fmapp/src/features/transactions/data/models/transaction.dart';
import 'package:fmapp/src/features/transactions/presentation/state/transaction_controller.dart';
import 'package:fmapp/src/features/auth/presentation/state/auth_controller.dart';
import 'package:fmapp/src/core/presentation/widgets/loading_indicator.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'dashboard_screen_test.mocks.dart';


@GenerateNiceMocks([
  MockSpec<FinancialAccountController>(),
  MockSpec<TransactionController>(),
  MockSpec<AuthController>(), // Added AuthController here
  MockSpec<User>()
])
void main() {
  final testUser = User(id: 'user123', appMetadata: {}, userMetadata: {}, aud: 'aud', createdAt: '2023-01-01T00:00:00Z');

  final account1 = FinancialAccount(isarId: 1, supabaseId: 'acc1', userId: 'user123', accountName: 'Bank A', accountType: AccountType.bankAccount, initialBalance: 1000, dateAdded: DateTime.now(), createdAt: DateTime.now(), updatedAt: DateTime.now());
  final account2 = FinancialAccount(isarId: 2, supabaseId: 'acc2', userId: 'user123', accountName: 'Cash', accountType: AccountType.cash, initialBalance: 200, dateAdded: DateTime.now(), createdAt: DateTime.now(), updatedAt: DateTime.now());

  final tx1 = Transaction(isarId:1, supabaseId: 'tx1', userId: 'user123', affectedAccountId: 'acc1', transactionDate: DateTime.now().subtract(const Duration(days:1)), amount: 50, transactionType: TransactionType.expenseDebit, descriptionNotes: 'Lunch', createdAt: DateTime.now(), updatedAt: DateTime.now());
  final tx2 = Transaction(isarId:2, supabaseId: 'tx2', userId: 'user123', affectedAccountId: 'acc2', transactionDate: DateTime.now(), amount: 100, transactionType: TransactionType.incomeCredit, descriptionNotes: 'Pocket Money', createdAt: DateTime.now(), updatedAt: DateTime.now());
  final tx3 = Transaction(isarId:3, supabaseId: 'tx3', userId: 'user123', affectedAccountId: 'acc1', transactionDate: DateTime.now().subtract(const Duration(days:2)), amount: 20, transactionType: TransactionType.expenseDebit, descriptionNotes: 'Coffee', createdAt: DateTime.now(), updatedAt: DateTime.now());


  Widget createWidgetUnderTest({
    AsyncValue<List<FinancialAccount>> accountsStream = const AsyncData([]),
    Map<String, double> currentBalances = const {},
    AsyncValue<List<Transaction>> transactionsStream = const AsyncData([]),
    MockFinancialAccountController? mockFAController,
    MockTransactionController? mockTxController,
  }) {
    final effectiveFAController = mockFAController ?? MockFinancialAccountController();
    final effectiveTxController = mockTxController ?? MockTransactionController();

    if (mockFAController == null) {
        when(effectiveFAController.syncFinancialAccounts()).thenAnswer((_) async {});
        when(effectiveFAController.state).thenReturn(const AsyncData([])); // Default state
    }
    if (mockTxController == null) {
        when(effectiveTxController.syncTransactions(accountIdFilter: anyNamed('accountIdFilter'))).thenAnswer((_) async {});
        when(effectiveTxController.state).thenReturn(const AsyncData([])); // Default state
    }

    final mockAuthController = MockAuthController();
    when(mockAuthController.state).thenReturn(AsyncData(testUser));
    when(mockAuthController.build()).thenAnswer((_) async => testUser);
    when(mockAuthController.signOut()).thenAnswer((_) async {});


    return ProviderScope(
      overrides: [
        financialAccountsStreamProvider(false).overrideWith((ref) => Stream.value(
            accountsStream.when(data: (d) => d, loading: () => [], error: (e,s) => []))
        ),
        for (var entry in currentBalances.entries)
          currentBalanceProvider(entry.key).overrideWithValue(entry.value),
        transactionsStreamProvider(null).overrideWith((ref) => Stream.value(
            transactionsStream.when(data: (d) => d, loading: () => [], error: (e,s) => []))
        ),
        authControllerProvider.overrideWith((_) => mockAuthController ),
        financialAccountControllerProvider.overrideWith((_) => effectiveFAController),
        transactionControllerProvider.overrideWith((_) => effectiveTxController),

      ],
      child: const MaterialApp(home: DashboardScreen()),
    );
  }

  group('DashboardView Widget Tests (within DashboardScreen)', () {
    testWidgets('shows loading indicators when data is loading', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        accountsStream: const AsyncLoading(),
        transactionsStream: const AsyncLoading(),
      ));
      expect(find.widgetWithText(LoadingIndicator, "Loading accounts..."), findsOneWidget);
      expect(find.widgetWithText(LoadingIndicator, "Loading transactions..."), findsOneWidget);
    });

    testWidgets('displays account summaries with dynamic balances', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        accountsStream: AsyncData([account1, account2]),
        currentBalances: {'acc1': 930, 'acc2': 300},
      ));

      expect(find.text('Bank A: ETB 930.00'), findsOneWidget);
      expect(find.text('Cash: ETB 300.00'), findsOneWidget);
      expect(find.textContaining('Total Active Accounts: 2'), findsOneWidget);
    });

    testWidgets('displays recent transactions (up to 5)', (WidgetTester tester) async {
      final List<Transaction> allTxs = [tx2, tx1, tx3];
      allTxs.sort((a,b) => b.transactionDate.compareTo(a.transactionDate));

      await tester.pumpWidget(createWidgetUnderTest(
        transactionsStream: AsyncData(allTxs),
      ));

      expect(find.text('Pocket Money'), findsOneWidget);
      expect(find.textContaining('+ ETB 100.00'), findsOneWidget);

      expect(find.text('Lunch'), findsOneWidget);
      expect(find.textContaining('- ETB 50.00'), findsOneWidget);

      expect(find.text('Coffee'), findsOneWidget);
      expect(find.textContaining('- ETB 20.00'), findsOneWidget);
    });

    testWidgets('shows empty states if no accounts or transactions', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        accountsStream: const AsyncData([]),
        transactionsStream: const AsyncData([]),
      ));

      expect(find.text("No active accounts to summarize."), findsOneWidget);
      expect(find.text("No transactions yet."), findsOneWidget);
    });

    testWidgets('RefreshIndicator calls sync methods on controllers', (WidgetTester tester) async {
      final mockFAController = MockFinancialAccountController();
      final mockTxController = MockTransactionController();

      when(mockFAController.syncFinancialAccounts()).thenAnswer((_) async {});
      when(mockTxController.syncTransactions(accountIdFilter: null)).thenAnswer((_) async {});
      when(mockFAController.state).thenReturn(const AsyncData([]));
      when(mockTxController.state).thenReturn(const AsyncData([]));


      await tester.pumpWidget(createWidgetUnderTest(
        accountsStream: const AsyncData([]),
        transactionsStream: const AsyncData([]),
        mockFAController: mockFAController,
        mockTxController: mockTxController,
      ));

      await tester.fling(find.byType(DashboardView), const Offset(0.0, 300.0), 1000.0);
      await tester.pumpAndSettle();

      verify(mockFAController.syncFinancialAccounts()).called(1);
      verify(mockTxController.syncTransactions(accountIdFilter: null)).called(1);
    });
  });
}
