import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';

part 'loan_debt.g.dart'; // Isar generator will create this file

enum LoanDebtType {
  loanGivenToFriend, // Money I lent out
  debtOwedToFriend,  // Money I borrowed
}

extension LoanDebtTypeExtension on LoanDebtType {
  String toJson() => name;
  static LoanDebtType fromJson(String json) {
    return LoanDebtType.values.firstWhere((e) => e.name == json,
                orElse: () => LoanDebtType.loanGivenToFriend); // Default or throw
  }
  String get displayName {
    switch (this) {
      case LoanDebtType.loanGivenToFriend:
        return 'Loan Given';
      case LoanDebtType.debtOwedToFriend:
        return 'Debt Owed';
      default:
        return name;
    }
  }
}

enum LoanDebtStatus {
  active,
  partiallyPaid,
  paidOff,
}

extension LoanDebtStatusExtension on LoanDebtStatus {
  String toJson() => name;
  static LoanDebtStatus fromJson(String json) {
    return LoanDebtStatus.values.firstWhere((e) => e.name == json,
                orElse: () => LoanDebtStatus.active); // Default or throw
  }
  String get displayName {
    switch (this) {
      case LoanDebtStatus.active:
        return 'Active';
      case LoanDebtStatus.partiallyPaid:
        return 'Partially Paid';
      case LoanDebtStatus.paidOff:
        return 'Paid Off';
      default:
        return name;
    }
  }
}

@Collection(inheritance: false)
class LoanDebt extends Equatable {
  final Id isarId;

  @Index(unique: false, replace: false)
  final String userId;

  @Index(unique: false, replace: false) // For querying loans by friend
  final String associatedFriendId; // Supabase ID of the Friend

  @Enumerated(EnumType.name)
  final LoanDebtType type;

  final double initialAmount;
  final double outstandingAmount; // This will be updated with repayments

  final DateTime dateInitiated;
  final DateTime? dueDate; // Optional

  final String? description;

  @Enumerated(EnumType.name)
  final LoanDebtStatus status;

  // "Cash" or the supabaseId of one of the user's FinancialAccount
  final String initialTransactionMethod;

  final DateTime createdAt;
  final DateTime updatedAt;

  @Index(unique: true, replace: true, caseSensitive: true)
  final String? supabaseId;

  // We might also need a list of associated repayment IDs or objects later.
  // For P0, repayments will update outstandingAmount and status.

  const LoanDebt({
    this.isarId = Isar.autoIncrement,
    required this.userId,
    required this.associatedFriendId,
    required this.type,
    required this.initialAmount,
    required this.outstandingAmount,
    required this.dateInitiated,
    this.dueDate,
    this.description,
    required this.status,
    required this.initialTransactionMethod, // "Cash" or FinancialAccount.supabaseId
    required this.createdAt,
    required this.updatedAt,
    this.supabaseId,
  });

  @override
  List<Object?> get props => [
        isarId, userId, associatedFriendId, type, initialAmount, outstandingAmount,
        dateInitiated, dueDate, description, status, initialTransactionMethod,
        createdAt, updatedAt, supabaseId,
      ];

  factory LoanDebt.fromMap(Map<String, dynamic> map) {
    return LoanDebt(
      userId: map['user_id'] as String,
      associatedFriendId: map['associated_friend_id'] as String,
      type: LoanDebtTypeExtension.fromJson(map['type'] as String),
      initialAmount: (map['initial_amount'] as num).toDouble(),
      outstandingAmount: (map['outstanding_amount'] as num).toDouble(),
      dateInitiated: DateTime.parse(map['date_initiated'] as String),
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date'] as String) : null,
      description: map['description'] as String?,
      status: LoanDebtStatusExtension.fromJson(map['status'] as String),
      initialTransactionMethod: map['initial_transaction_method'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      supabaseId: map['id'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (supabaseId != null) 'id': supabaseId,
      'user_id': userId,
      'associated_friend_id': associatedFriendId,
      'type': type.toJson(),
      'initial_amount': initialAmount,
      'outstanding_amount': outstandingAmount,
      'date_initiated': dateInitiated.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'description': description,
      'status': status.toJson(),
      'initial_transaction_method': initialTransactionMethod,
      // Supabase handles created_at on insert, and updated_at via trigger
    };
  }

  LoanDebt copyWith({
    Id? isarId,
    String? userId,
    String? associatedFriendId,
    LoanDebtType? type,
    double? initialAmount,
    double? outstandingAmount,
    DateTime? dateInitiated,
    DateTime? dueDate,
    String? description,
    LoanDebtStatus? status,
    String? initialTransactionMethod,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? supabaseId,
    bool setDueDateNull = false,
    bool setDescriptionNull = false,
    bool setSupabaseIdNull = false,
  }) {
    return LoanDebt(
      isarId: isarId ?? this.isarId,
      userId: userId ?? this.userId,
      associatedFriendId: associatedFriendId ?? this.associatedFriendId,
      type: type ?? this.type,
      initialAmount: initialAmount ?? this.initialAmount,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      dateInitiated: dateInitiated ?? this.dateInitiated,
      dueDate: setDueDateNull ? null : (dueDate ?? this.dueDate),
      description: setDescriptionNull ? null : (description ?? this.description),
      status: status ?? this.status,
      initialTransactionMethod: initialTransactionMethod ?? this.initialTransactionMethod,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supabaseId: setSupabaseIdNull ? null : (supabaseId ?? this.supabaseId),
    );
  }
}
