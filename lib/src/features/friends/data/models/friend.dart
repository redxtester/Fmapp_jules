import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';

part 'friend.g.dart'; // Isar generator will create this file

@Collection(inheritance: false)
class Friend extends Equatable {
  final Id isarId;

  @Index(unique: false, replace: false) // UserID is not unique by itself for friends
  final String userId;

  @Index(unique: false, replace: false, caseSensitive: false) // Friend names might not be unique per user either
  final String friendName;

  @Index(unique: false, replace: false, caseSensitive: false) // Phone numbers might be shared or not unique
  final String? friendPhoneNumber; // Optional as per PRD 4.5.1

  final DateTime createdAt;
  final DateTime updatedAt;

  @Index(unique: true, replace: true, caseSensitive: true)
  final String? supabaseId;

  const Friend({
    this.isarId = Isar.autoIncrement,
    required this.userId,
    required this.friendName,
    this.friendPhoneNumber,
    required this.createdAt,
    required this.updatedAt,
    this.supabaseId,
  });

  @override
  List<Object?> get props => [
        isarId, userId, friendName, friendPhoneNumber,
        createdAt, updatedAt, supabaseId
      ];

  factory Friend.fromMap(Map<String, dynamic> map) {
    return Friend(
      // isarId is local
      userId: map['user_id'] as String,
      friendName: map['friend_name'] as String,
      friendPhoneNumber: map['friend_phone_number'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      supabaseId: map['id'] as String, // 'id' from Supabase
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (supabaseId != null) 'id': supabaseId,
      'user_id': userId,
      'friend_name': friendName,
      'friend_phone_number': friendPhoneNumber,
      // Supabase handles created_at on insert, and updated_at via trigger
    };
  }

  Friend copyWith({
    Id? isarId,
    String? userId,
    String? friendName,
    String? friendPhoneNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? supabaseId,
    bool setFriendPhoneNumberNull = false,
    bool setSupabaseIdNull = false,
  }) {
    return Friend(
      isarId: isarId ?? this.isarId,
      userId: userId ?? this.userId,
      friendName: friendName ?? this.friendName,
      friendPhoneNumber: setFriendPhoneNumberNull ? null : (friendPhoneNumber ?? this.friendPhoneNumber),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supabaseId: setSupabaseIdNull ? null : (supabaseId ?? this.supabaseId),
    );
  }
}
