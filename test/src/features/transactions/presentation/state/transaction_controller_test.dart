import 'package:flutter_test/flutter_test.dart';
import 'package:fmapp/src/features/auth/data/repositories/auth_repository.dart';
import 'package:fmapp/src/features/transactions/data/models/transaction.dart';
import 'package:fmapp/src/features/transactions/data/repositories/transaction_repository.dart';
import 'package:fmapp/src/features/transactions/presentation/state/transaction_controller.dart';
import 'package:fmapp/src/features/financial_accounts/data/models/financial_account.dart';
import 'package:fmapp/src/features/financial_accounts/data/repositories/financial_account_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

// Import generated mocks
import 'transaction_controller_test.mocks.dart';


@GenerateNiceMocks([
  MockSpec<AuthRepository>(),
  MockSpec<TransactionRepository>(),
  MockSpec<FinancialAccountRepository>()
])
void main() {
  // --- Tests for currentBalanceProvider ---
  group('currentBalanceProvider Tests', () {
    late ProviderContainer container;
    late MockTransactionRepository mockTransactionRepository;
    late MockFinancialAccountRepository mockFinancialAccountRepository;

    const user123 = 'user123';
    final account1Id = 'acc_supa_id_1';
    final account2Id = 'acc_supa_id_2';
    final account3Id = 'acc_supa_id_3'; // Another account not involved in some transfers

    final account1 = FinancialAccount(isarId: 1, supabaseId: account1Id, userId: user123, accountName: 'Account 1 (Source)', accountType: AccountType.bankAccount, initialBalance: 1000.0, dateAdded: DateTime(2023,1,1), createdAt: DateTime(2023,1,1), updatedAt: DateTime(2023,1,1));
    final account2 = FinancialAccount(isarId: 2, supabaseId: account2Id, userId: user123, accountName: 'Account 2 (Dest)', accountType: AccountType.cash, initialBalance: 500.0, dateAdded: DateTime(2023,1,1), createdAt: DateTime(2023,1,1), updatedAt: DateTime(2023,1,1));
    final account3 = FinancialAccount(isarId: 3, supabaseId: account3Id, userId: user123, accountName: 'Account 3 (Other)', accountType: AccountType.onlineMoney, initialBalance: 200.0, dateAdded: DateTime(2023,1,1), createdAt: DateTime(2023,1,1), updatedAt: DateTime(2023,1,1));


    setUp(() {
      mockTransactionRepository = MockTransactionRepository();
      mockFinancialAccountRepository = MockFinancialAccountRepository();
    });

    tearDown(() {
      container.dispose();
    });

    // Helper to setup container with mocks for a specific test
    ProviderContainer setupContainer(List<Transaction> transactionsForAccount1, List<Transaction> transactionsForAccount2, List<Transaction> transactionsForAccount3) {
      // Default: watchFinancialAccountBySupabaseIdLocal returns the specific account
      when(mockFinancialAccountRepository.watchFinancialAccountBySupabaseIdLocal(account1Id))
          .thenAnswer((_) => Stream.value(account1));
      when(mockFinancialAccountRepository.watchFinancialAccountBySupabaseIdLocal(account2Id))
          .thenAnswer((_) => Stream.value(account2));
      when(mockFinancialAccountRepository.watchFinancialAccountBySupabaseIdLocal(account3Id))
          .thenAnswer((_) => Stream.value(account3));

      when(mockTransactionRepository.watchTransactionsLocal(account1Id))
          .thenAnswer((_) => Stream.value(transactionsForAccount1));
      when(mockTransactionRepository.watchTransactionsLocal(account2Id))
          .thenAnswer((_) => Stream.value(transactionsForAccount2));
      when(mockTransactionRepository.watchTransactionsLocal(account3Id))
          .thenAnswer((_) => Stream.value(transactionsForAccount3));

      return ProviderContainer(overrides: [
        financialAccountRepositoryProvider.overrideWithValue(mockFinancialAccountRepository),
        transactionRepositoryProvider.overrideWithValue(mockTransactionRepository),
      ]);
    }

    test('calculates balance correctly with no transactions', () {
      container = setupContainer([], [], []);
      expect(container.read(currentBalanceProvider(account1Id)), 1000.0);
    });

    test('calculates balance correctly with income transactions', () {
      final incomeTx = [Transaction(userId: user123, affectedAccountId: account1Id, transactionDate: DateTime(2023,1,2), amount: 200, transactionType: TransactionType.incomeCredit, createdAt: DateTime.now(), updatedAt: DateTime.now())];
      container = setupContainer(incomeTx, [], []);
      expect(container.read(currentBalanceProvider(account1Id)), 1200.0);
    });
     test('calculates balance correctly with expense transactions', () {
      final expenseTx = [Transaction(userId: user123, affectedAccountId: account1Id, transactionDate: DateTime(2023,1,2), amount: 100, transactionType: TransactionType.expenseDebit, createdAt: DateTime.now(), updatedAt: DateTime.now())];
      container = setupContainer(expenseTx, [], []);
      expect(container.read(currentBalanceProvider(account1Id)), 900.0);
    });


    // --- New tests specifically for Internal Transfers ---
    test('calculates balance: source account debited for internal transfer', () {
      final transferTx = Transaction(
        userId: user123, affectedAccountId: account1Id, // Source
        counterpartyAccountId: account2Id, // Destination
        transactionDate: DateTime(2023,1,5), amount: 300,
        transactionType: TransactionType.expenseDebit,
        isInternalTransfer: true,
        createdAt: DateTime.now(), updatedAt: DateTime.now()
      );
      container = setupContainer([transferTx], [], []);
      expect(container.read(currentBalanceProvider(account1Id)), 1000.0 - 300.0); // 700.0
    });

    test('calculates balance: destination account credited for internal transfer', () {
      final transferTx = Transaction(
        userId: user123, affectedAccountId: account1Id, // Source
        counterpartyAccountId: account2Id, // Destination
        transactionDate: DateTime(2023,1,5), amount: 300,
        transactionType: TransactionType.expenseDebit,
        isInternalTransfer: true,
        createdAt: DateTime.now(), updatedAt: DateTime.now()
      );
      container = setupContainer([], [transferTx], []);
      expect(container.read(currentBalanceProvider(account2Id)), 500.0 + 300.0); // 800.0
    });

    test('calculates balance: account not involved in internal transfer is unaffected', () {
      container = setupContainer([], [], []);
      expect(container.read(currentBalanceProvider(account3Id)), 200.0); // Initial balance
    });

    test('calculates balance correctly with mixed regular and internal transfer (source)', () {
      final regularExpense = Transaction(userId: user123, affectedAccountId: account1Id, transactionDate: DateTime(2023,1,2), amount: 100, transactionType: TransactionType.expenseDebit, createdAt: DateTime.now(), updatedAt: DateTime.now());
      final transferOut = Transaction(userId: user123, affectedAccountId: account1Id, counterpartyAccountId: account2Id, transactionDate: DateTime(2023,1,5), amount: 200, transactionType: TransactionType.expenseDebit, isInternalTransfer: true, createdAt: DateTime.now(), updatedAt: DateTime.now());
      container = setupContainer([regularExpense, transferOut], [], []);
      expect(container.read(currentBalanceProvider(account1Id)), 1000.0 - 100.0 - 200.0); // 700.0
    });

    test('calculates balance correctly with mixed regular and internal transfer (destination)', () {
      final regularIncome = Transaction(userId: user123, affectedAccountId: account2Id, transactionDate: DateTime(2023,1,2), amount: 100, transactionType: TransactionType.incomeCredit, createdAt: DateTime.now(), updatedAt: DateTime.now());
      final transferIn = Transaction(userId: user123, affectedAccountId: account1Id, counterpartyAccountId: account2Id, transactionDate: DateTime(2023,1,5), amount: 200, transactionType: TransactionType.expenseDebit, isInternalTransfer: true, createdAt: DateTime.now(), updatedAt: DateTime.now());
      container = setupContainer([], [regularIncome, transferIn], []);
      expect(container.read(currentBalanceProvider(account2Id)), 500.0 + 100.0 + 200.0); // 800.0
    });

    test('ignores transactions dated before account.dateAdded', () {
      final accountAddedLater = FinancialAccount(isarId: 4, supabaseId: "acc4_later", userId: user123, accountName: "New Acc", accountType: AccountType.bankAccount, initialBalance: 0, dateAdded: DateTime(2023,2,1), createdAt: DateTime.now(), updatedAt: DateTime.now());
      final oldTransaction = Transaction(userId: user123, affectedAccountId: "acc4_later", transactionDate: DateTime(2023,1,15), amount: 100, transactionType: TransactionType.incomeCredit, createdAt: DateTime.now(), updatedAt: DateTime.now());

      when(mockFinancialAccountRepository.watchFinancialAccountBySupabaseIdLocal("acc4_later"))
          .thenAnswer((_) => Stream.value(accountAddedLater));
      when(mockTransactionRepository.watchTransactionsLocal("acc4_later"))
          .thenAnswer((_) => Stream.value([oldTransaction]));

      container = ProviderContainer(overrides: [
        financialAccountRepositoryProvider.overrideWithValue(mockFinancialAccountRepository),
        transactionRepositoryProvider.overrideWithValue(mockTransactionRepository),
      ]);

      expect(container.read(currentBalanceProvider("acc4_later")), 0.0); // Old transaction should be ignored
    });

  });
}

extension ProviderContainerPump on ProviderContainer {
  Future<void> pump([Duration duration = const Duration(milliseconds: 0)]) {
    return Future.delayed(duration);
  }
}
