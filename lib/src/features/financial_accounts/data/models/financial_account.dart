import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';

part 'financial_account.g.dart'; // Isar generator will create this file

enum AccountType {
  bankAccount,
  mobileWallet,
  onlineMoney,
  cash,
}

// Helper extension for AccountType to handle string conversion for Supabase
extension AccountTypeExtension on AccountType {
  String toJson() => name; // Using .name from Dart 2.15+ enums
  static AccountTypefromJson(String json) {
    return AccountType.values.firstWhere((e) => e.name == json, orElse: () => AccountType.bankAccount); // Default or throw error
  }
}


@Collection(inheritance: false)
class FinancialAccount extends Equatable {
  final Id isarId; // Auto-incrementing ID for Isar

  @Index(unique: false, replace: false)
  final String userId; // Foreign key to Supabase auth.users.id

  final String accountName;
  final String? accountIdentifier; // e.g., account number, phone for mobile wallet

  @Enumerated(EnumType.name) // Store enum as string in Isar
  final AccountType accountType;

  // This would ideally link to SimCard's supabaseId or isarId if SIMs are also in Isar
  // For simplicity in Isar, storing supabaseId of the SimCard if linked.
  // Or, if SimCards are also fully managed in Isar, this could be an IsarLink.
  // For now, assuming we store the SimCard's supabaseId as a string.
  @Index(unique: false, replace: false)
  final String? linkedSimSupabaseId;

  final double initialBalance;
  final DateTime dateAdded; // When account was created in the system by user
  final String currency; // Default ETB as per PRD
  final bool isArchived;

  final DateTime createdAt; // Record creation timestamp in our system
  final DateTime updatedAt; // Record update timestamp in our system

  @Index(unique: true, replace: true, caseSensitive: true)
  final String? supabaseId; // Populated after syncing with Supabase (UUID)

  // Note: currentBalance is dynamically calculated as per PRD 4.2.1 and not stored here.

  const FinancialAccount({
    this.isarId = Isar.autoIncrement,
    required this.userId,
    required this.accountName,
    this.accountIdentifier,
    required this.accountType,
    this.linkedSimSupabaseId,
    required this.initialBalance,
    required this.dateAdded,
    this.currency = 'ETB', // Default currency
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
    this.supabaseId,
  });

  @override
  List<Object?> get props => [
        isarId,
        userId,
        accountName,
        accountIdentifier,
        accountType,
        linkedSimSupabaseId,
        initialBalance,
        dateAdded,
        currency,
        isArchived,
        createdAt,
        updatedAt,
        supabaseId,
      ];

  factory FinancialAccount.fromMap(Map<String, dynamic> map) {
    return FinancialAccount(
      // isarId is local, not from map
      userId: map['user_id'] as String,
      accountName: map['account_name'] as String,
      accountIdentifier: map['account_identifier'] as String?,
      accountType: AccountTypeExtension.fromJson(map['account_type'] as String),
      linkedSimSupabaseId: map['linked_sim_id'] as String?,
      initialBalance: (map['initial_balance'] as num).toDouble(),
      dateAdded: DateTime.parse(map['date_added'] as String),
      currency: map['currency'] as String? ?? 'ETB',
      isArchived: map['is_archived'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      supabaseId: map['id'] as String, // 'id' from Supabase
    );
  }

  Map<String, dynamic> toMap() {
    // For sending to Supabase
    return {
      if (supabaseId != null) 'id': supabaseId, // only for updates
      'user_id': userId,
      'account_name': accountName,
      'account_identifier': accountIdentifier,
      'account_type': accountType.toJson(), // Convert enum to string
      'linked_sim_id': linkedSimSupabaseId,
      'initial_balance': initialBalance,
      'date_added': dateAdded.toIso8601String(),
      'currency': currency,
      'is_archived': isArchived,
      // Supabase handles created_at on insert and updated_at via trigger
      // 'created_at': createdAt.toIso8601String(),
      // 'updated_at': updatedAt.toIso8601String(),
    };
  }

  FinancialAccount copyWith({
    Id? isarId,
    String? userId,
    String? accountName,
    String? accountIdentifier,
    AccountType? accountType,
    String? linkedSimSupabaseId,
    double? initialBalance,
    DateTime? dateAdded,
    String? currency,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? supabaseId,
    bool setAccountIdentifierNull = false,
    bool setLinkedSimSupabaseIdNull = false,
    bool setSupabaseIdNull = false,
  }) {
    return FinancialAccount(
      isarId: isarId ?? this.isarId,
      userId: userId ?? this.userId,
      accountName: accountName ?? this.accountName,
      accountIdentifier: setAccountIdentifierNull ? null : (accountIdentifier ?? this.accountIdentifier),
      accountType: accountType ?? this.accountType,
      linkedSimSupabaseId: setLinkedSimSupabaseIdNull ? null : (linkedSimSupabaseId ?? this.linkedSimSupabaseId),
      initialBalance: initialBalance ?? this.initialBalance,
      dateAdded: dateAdded ?? this.dateAdded,
      currency: currency ?? this.currency,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supabaseId: setSupabaseIdNull ? null : (supabaseId ?? this.supabaseId),
    );
  }
}
