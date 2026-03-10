import 'package:equatable/equatable.dart';

import 'task.dart';

/// A household group.
class Household extends Equatable {
  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;

  const Household({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
  });

  factory Household.fromMap(Map<String, dynamic> map) => Household(
        id: map['id'] as String,
        name: map['name'] as String,
        createdBy: map['created_by'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id];
}

/// A member within a household.
class HouseholdMember extends Equatable {
  final String userId;
  final String householdId;
  final String role; // 'admin', 'member'
  final DateTime? joinedAt;
  final ProfileRef? profile;

  const HouseholdMember({
    required this.userId,
    required this.householdId,
    required this.role,
    this.joinedAt,
    this.profile,
  });

  factory HouseholdMember.fromMap(Map<String, dynamic> map) {
    final profileMap = map['profiles'] as Map<String, dynamic>?;

    return HouseholdMember(
      userId: map['user_id'] as String,
      householdId: map['household_id'] as String? ?? '',
      role: map['role'] as String? ?? 'member',
      joinedAt: map['joined_at'] != null
          ? DateTime.tryParse(map['joined_at'] as String)
          : null,
      profile:
          profileMap != null ? ProfileRef.fromMap(profileMap) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'household_id': householdId,
        'role': role,
        'joined_at': joinedAt?.toIso8601String(),
        'profiles': profile?.toMap(),
      };

  @override
  List<Object?> get props => [userId, householdId];
}
