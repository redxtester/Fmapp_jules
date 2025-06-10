import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';

part 'sim_card.g.dart'; // Isar generator will create this file

@Collection(inheritance: false) // No inheritance for simplicity unless needed
class SimCard extends Equatable {
  final Id isarId; // Auto-incrementing ID for Isar, not synced with Supabase UUID directly

  @Index(unique: false, replace: false, caseSensitive: false) // user_id is not unique by itself
  final String userId; // Foreign key to Supabase auth.users.id / UserProfile.id

  @Index(unique: false, replace: false, caseSensitive: false) // phone_number is not globally unique, but per user
  final String phoneNumber;

  final String simNickname;
  final String? telecomProvider;
  final String? officialRegisteredName;
  final String? colorCode; // Storing as hex string e.g., "#FF0000" or material color name

  final DateTime createdAt;
  final DateTime updatedAt;

  // Supabase specific ID - this is the true unique ID from the backend
  // It's optional here because an Isar object might exist before it's synced to Supabase
  @Index(unique: true, replace: true, caseSensitive: true)
  final String? supabaseId;

  SimCard({
    this.isarId = Isar.autoIncrement, // Isar handles this
    required this.userId,
    required this.phoneNumber,
    required this.simNickname,
    this.telecomProvider,
    this.officialRegisteredName,
    this.colorCode,
    required this.createdAt,
    required this.updatedAt,
    this.supabaseId, // This will be populated after syncing with Supabase
  });

  @override
  List<Object?> get props => [
        isarId,
        userId,
        phoneNumber,
        simNickname,
        telecomProvider,
        officialRegisteredName,
        colorCode,
        createdAt,
        updatedAt,
        supabaseId,
      ];

  // From/To Map for Supabase (Isar uses its own mechanisms)
  // Note: isarId is not part of Supabase mapping. supabaseId is the 'id' in Supabase.
  factory SimCard.fromMap(Map<String, dynamic> map) {
    return SimCard(
      // isarId is local only, not from map
      userId: map['user_id'] as String,
      phoneNumber: map['phone_number'] as String,
      simNickname: map['sim_nickname'] as String,
      telecomProvider: map['telecom_provider'] as String?,
      officialRegisteredName: map['official_registered_name'] as String?,
      colorCode: map['color_code'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      supabaseId: map['id'] as String, // 'id' from Supabase is our supabaseId
    );
  }

  Map<String, dynamic> toMap() {
    // For sending to Supabase. 'id' (PK) is supabaseId.
    // 'user_id' will be set by RLS or default value from session if not explicitly provided.
    return {
      if (supabaseId != null) 'id': supabaseId, // only include for updates
      'user_id': userId, // Important for Supabase to link to the user
      'phone_number': phoneNumber,
      'sim_nickname': simNickname,
      'telecom_provider': telecomProvider,
      'official_registered_name': officialRegisteredName,
      'color_code': colorCode,
      // Supabase handles created_at on insert, and updated_at via trigger
      // 'created_at': createdAt.toIso8601String(),
      // 'updated_at': updatedAt.toIso8601String(),
    };
  }

  SimCard copyWith({
    Id? isarId,
    String? userId,
    String? phoneNumber,
    String? simNickname,
    String? telecomProvider,
    String? officialRegisteredName,
    String? colorCode,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? supabaseId,
    bool setOfficialRegisteredNameNull = false,
    bool setTelecomProviderNull = false,
    bool setColorCodeNull = false,
    bool setSupabaseIdNull = false,
  }) {
    return SimCard(
      isarId: isarId ?? this.isarId,
      userId: userId ?? this.userId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      simNickname: simNickname ?? this.simNickname,
      telecomProvider: setTelecomProviderNull ? null : (telecomProvider ?? this.telecomProvider),
      officialRegisteredName: setOfficialRegisteredNameNull ? null : (officialRegisteredName ?? this.officialRegisteredName),
      colorCode: setColorCodeNull ? null : (colorCode ?? this.colorCode),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supabaseId: setSupabaseIdNull ? null : (supabaseId ?? this.supabaseId),
    );
  }
}
