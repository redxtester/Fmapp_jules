import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';

part 'transaction.g.dart'; // Isar generator will create this file

enum TransactionType {
  incomeCredit, // PRD: "Income/Credit"
  expenseDebit, // PRD: "Expense/Debit"
}

extension TransactionTypeExtension on TransactionType {
  String toJson() => name;
  static TransactionType fromJson(String json) {
    return TransactionType.values.firstWhere((e) => e.name == json,
                orElse: () => TransactionType.expenseDebit); // Default or throw
  }
  String get displayName {
    switch (this) {
      case TransactionType.incomeCredit:
        return 'Income / Credit';
      case TransactionType.expenseDebit:
        return 'Expense / Debit';
      default:
        return name;
    }
  }
}

@Collection(inheritance: false)
class Transaction extends Equatable {
  final Id isarId;

  @Index(unique: false, replace: false)
  final String userId;

  @Index(unique: false, replace: false)
  final String affectedAccountId; // Supabase ID of the FinancialAccount

  final DateTime transactionDate;
  final double amount;

  @Enumerated(EnumType.name)
  final TransactionType transactionType;

  final String currency; // Default ETB

  final String? descriptionNotes;
  final String? categoryTag;
  final String? payerSenderRaw;
  final String? payeeReceiverRaw;
  final String? referenceNumber;

  final DateTime createdAt;
  final DateTime updatedAt;

  @Index(unique: true, replace: true, caseSensitive: true)
  final String? supabaseId;

  const Transaction({
    this.isarId = Isar.autoIncrement,
    required this.userId,
    required this.affectedAccountId,
    required this.transactionDate,
    required this.amount,
    required this.transactionType,
    this.currency = 'ETB',
    this.descriptionNotes,
    this.categoryTag,
    this.payerSenderRaw,
    this.payeeReceiverRaw,
    this.referenceNumber,
    required this.createdAt,
    required this.updatedAt,
    this.supabaseId,
  });

  @override
  List<Object?> get props => [
        isarId, userId, affectedAccountId, transactionDate, amount, transactionType,
        currency, descriptionNotes, categoryTag, payerSenderRaw, payeeReceiverRaw,
        referenceNumber, createdAt, updatedAt, supabaseId,
      ];

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      userId: map['user_id'] as String,
      affectedAccountId: map['affected_account_id'] as String,
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      amount: (map['amount'] as num).toDouble(),
      transactionType: TransactionTypeExtension.fromJson(map['transaction_type'] as String),
      currency: map['currency'] as String? ?? 'ETB',
      descriptionNotes: map['description_notes'] as String?,
      categoryTag: map['category_tag'] as String?,
      payerSenderRaw: map['payer_sender_raw'] as String?,
      payeeReceiverRaw: map['payee_receiver_raw'] as String?,
      referenceNumber: map['reference_number'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      supabaseId: map['id'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (supabaseId != null) 'id': supabaseId,
      'user_id': userId,
      'affected_account_id': affectedAccountId,
      'transaction_date': transactionDate.toIso8601String(),
      'amount': amount,
      'transaction_type': transactionType.toJson(),
      'currency': currency,
      'description_notes': descriptionNotes,
      'category_tag': categoryTag,
      'payer_sender_raw': payerSenderRaw,
      'payee_receiver_raw': payeeReceiverRaw,
      'reference_number': referenceNumber,
    };
  }

  Transaction copyWith({
    Id? isarId,
    String? userId,
    String? affectedAccountId,
    DateTime? transactionDate,
    double? amount,
    TransactionType? transactionType,
    String? currency,
    String? descriptionNotes,
    String? categoryTag,
    String? payerSenderRaw,
    String? payeeReceiverRaw,
    String? referenceNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? supabaseId,
    bool setDescNull = false,
    bool setCatNull = false,
    bool setPayerNull = false,
    bool setPayeeNull = false,
    bool setRefNull = false,
    bool setSupabaseIdNull = false,
  }) {
    return Transaction(
      isarId: isarId ?? this.isarId,
      userId: userId ?? this.userId,
      affectedAccountId: affectedAccountId ?? this.affectedAccountId,
      transactionDate: transactionDate ?? this.transactionDate,
      amount: amount ?? this.amount,
      transactionType: transactionType ?? this.transactionType,
      currency: currency ?? this.currency,
      descriptionNotes: setDescNull ? null : (descriptionNotes ?? this.descriptionNotes),
      categoryTag: setCatNull ? null : (categoryTag ?? this.categoryTag),
      payerSenderRaw: setPayerNull ? null : (payerSenderRaw ?? this.payerSenderRaw),
      payeeReceiverRaw: setPayeeNull ? null : (payeeReceiverRaw ?? this.payeeReceiverRaw),
      referenceNumber: setRefNull ? null : (referenceNumber ?? this.referenceNumber),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supabaseId: setSupabaseIdNull ? null : (supabaseId ?? this.supabaseId),
    );
  }
}
