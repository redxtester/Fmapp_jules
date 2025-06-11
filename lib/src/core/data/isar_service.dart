import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import Isar collection schemas
import 'package:fmapp/src/features/auth/data/models/user_profile.dart';
import 'package:fmapp/src/features/sim_cards/data/models/sim_card.dart';
import 'package:fmapp/src/features/financial_accounts/data/models/financial_account.dart';
import 'package:fmapp/src/features/transactions/data/models/transaction.dart';
import 'package:fmapp/src/features/friends/data/models/friend.dart';
import 'package:fmapp/src/features/loans/data/models/loan_debt.dart'; // Added LoanDebt schema import

final isarInstanceProvider = Provider<Isar>((ref) {
  throw Exception("Isar instance not initialized. Ensure IsarService.init() is called at startup and isarInstanceProvider is overridden.");
});

class IsarService {
  late final Isar _isar;
  Isar get instance => _isar;

  IsarService();

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    try {
      _isar = await Isar.open(
        [
          UserProfileSchema,
          SimCardSchema,
          FinancialAccountSchema,
          TransactionSchema,
          FriendSchema,
          LoanDebtSchema, // Added LoanDebtSchema to the list
        ],
        directory: dir.path,
        name: 'fmappLocalDB',
      );
      print("Isar initialized successfully at ${dir.path}/fmappLocalDB.isar");
    } catch (e) {
      print("Error initializing Isar: $e");
      rethrow;
    }
  }

  Isar get db => _isar;

  Future<void> clearDatabase() async {
    await _isar.writeTxn(() async => await _isar.clear());
    print("Isar database cleared.");
  }

  Future<void> saveUserProfile(UserProfile userProfile) async {
    await _isar.writeTxn(() async {
      final existing = await _isar.userProfiles.filter().idEqualTo(userProfile.id).findFirst();
      if (existing != null) {
        await _isar.userProfiles.clear();
        await _isar.userProfiles.put(userProfile);
      } else {
        await _isar.userProfiles.put(userProfile);
      }
    });
  }

  Future<UserProfile?> getUserProfile(String userId) async {
    return await _isar.userProfiles.filter().idEqualTo(userId).findFirst();
  }

  Future<void> clearUserProfiles() async {
    await _isar.writeTxn(() async => await _isar.userProfiles.clear());
  }
}
