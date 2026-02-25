// lib/shared/models/group.dart
import 'dart:convert';
import 'package:equatable/equatable.dart';

class Group extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String createdBy; // User ID
  final DateTime createdAt;
  final List<String> memberIds;
  final String currency;

  const Group({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.createdBy,
    required this.createdAt,
    required this.memberIds,
    this.currency = 'USD',
  });

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
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Temporary ID generation
      name: name,
      description: description,
      imageUrl: imageUrl,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      memberIds: [createdBy],
      currency: currency,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageURL': imageUrl,
      'createdBy': createdBy,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'memberIds': jsonEncode(memberIds),
      'currency': currency,
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      imageUrl: map['imageURL'] as String?,
      createdBy: map['createdBy'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      memberIds: map['memberIds'] is String
          ? List<String>.from(jsonDecode(map['memberIds'] as String))
          : List<String>.from(map['memberIds'] ?? []),
      currency: map['currency'] as String? ?? 'USD',
    );
  }
}
