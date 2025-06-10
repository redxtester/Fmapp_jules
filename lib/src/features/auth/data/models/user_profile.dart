import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String id; // Corresponds to Supabase auth.users.id
  final String? email;
  final String? pinHash;
  final bool biometricsEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    this.email,
    this.pinHash,
    this.biometricsEnabled = false,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      email: map['email'] as String?,
      pinHash: map['pin_hash'] as String?,
      biometricsEnabled: map['biometrics_enabled'] as bool? ?? false,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    // id, email, createdAt, updatedAt are typically handled by Supabase/triggers
    // and might not be part of client update payload for this specific table.
    // Email is primarily managed in auth.users.
    if (pinHash != null) {
      map['pin_hash'] = pinHash;
    }
    // Only include biometrics_enabled if you intend to update it.
    // If it's part of a larger update, include it.
    // For partial updates, only include fields that changed.
    map['biometrics_enabled'] = biometricsEnabled;
    return map;
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? pinHash,
    bool? biometricsEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool setPinHashNull = false,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      pinHash: setPinHashNull ? null : (pinHash ?? this.pinHash),
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, email, pinHash, biometricsEnabled, createdAt, updatedAt];
}
