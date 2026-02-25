// lib/shared/models/friend.dart
import 'package:equatable/equatable.dart';

class Friend extends Equatable {
  final String id;
  final String userId1; // One user ID
  final String userId2; // Other user ID
  final double balance; // Positive if user1 is owed, negative if user1 owes. 
  // Note: Perspective matters. This balance is "Relative to userId1".
  // If stored as a single document for relationship, we need a convention.
  // Convention: userId1 < userId2 (sorted) to ensure uniqueness? 
  // Or just store two documents per friendship for easier querying?
  // Let's assume two documents for easier querying: "My friend X".
  
  final String friendName;
  final String? friendEmail;
  final String? friendImageUrl;
  
  const Friend({
    required this.id,
    required this.userId1,
    required this.userId2,
    this.balance = 0.0,
    required this.friendName,
    this.friendEmail,
    this.friendImageUrl,
  });

  @override
  List<Object?> get props => [
        id,
        userId1,
        userId2,
        balance,
        friendName,
        friendEmail,
        friendImageUrl,
      ];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId1': userId1,
      'userId2': userId2,
      'balance': balance,
      'friendName': friendName,
      'friendEmail': friendEmail,
      'friendImageUrl': friendImageUrl,
    };
  }

  factory Friend.fromMap(Map<String, dynamic> map) {
    return Friend(
      id: map['id'] as String,
      userId1: map['userId1'] as String,
      userId2: map['userId2'] as String,
      balance: (map['balance'] as num).toDouble(),
      friendName: map['friendName'] as String,
      friendEmail: map['friendEmail'] as String?,
      friendImageUrl: map['friendImageUrl'] as String?,
    );
  }
}
