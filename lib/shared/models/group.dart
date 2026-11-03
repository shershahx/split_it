import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class Group extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String createdBy; // User ID
  final DateTime createdAt;
  final List<String> memberIds;
  final String currency;
  final int memberCount;
  final List<GroupMember> members;

  const Group({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.createdBy,
    required this.createdAt,
    required this.memberIds,
    this.currency = 'USD',
    int? memberCount,
    this.members = const [],
  }) : memberCount = memberCount ?? memberIds.length;

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        imageUrl,
        createdBy,
        createdAt,
        memberIds,
        currency,
        memberCount,
        members,
      ];

  /// Returns a copy with optionally overridden fields.
  Group copyWith({
    String? name,
    String? description,
    String? imageUrl,
    List<String>? memberIds,
    String? currency,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      createdBy: createdBy,
      createdAt: createdAt,
      memberIds: memberIds ?? this.memberIds,
      currency: currency ?? this.currency,
      memberCount: memberIds?.length ?? memberCount,
      members: members,
    );
  }

  // Factory for creating a new empty group
  factory Group.create({
    required String name,
    required String createdBy,
    String? description,
    String? imageUrl,
    String currency = 'USD',
  }) {
    return Group(
      id: const Uuid().v4(),
<<<<<<< HEAD
      name: name,
      description: description,
=======
      name: name.trim(),
      description: description?.trim(),
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
      imageUrl: imageUrl,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      memberIds: [createdBy],
      currency: currency,
    );
  }

  /// Only group columns are written. Membership is managed by the database.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'created_by': createdBy,
      'currency': currency,
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    final memberRows = (map['group_members'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final members = memberRows
        .where((row) => row.containsKey('user_id'))
        .map(GroupMember.fromMap)
        .toList(growable: false);
    final count = memberRows.isNotEmpty && memberRows.first.containsKey('count')
        ? memberRows.first['count'] as int
        : members.length;
    return Group(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      memberIds: List.unmodifiable(members.map((member) => member.userId)),
      currency: map['currency'] as String? ?? 'USD',
      memberCount: count,
      members: List.unmodifiable(members),
    );
  }
}

class GroupMember extends Equatable {
  final String userId;
  final String displayName;
  final String role;

  const GroupMember({
    required this.userId,
    required this.displayName,
    required this.role,
  });

  bool get canInvite => role == 'owner' || role == 'admin';

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return GroupMember(
      userId: map['user_id'] as String,
      displayName: profile?['display_name'] as String? ?? 'Member',
      role: map['role'] as String,
    );
  }

  @override
  List<Object?> get props => [userId, displayName, role];
}
