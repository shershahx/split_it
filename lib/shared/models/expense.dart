// lib/shared/models/expense.dart
import 'dart:convert';
import 'package:equatable/equatable.dart';

class Expense extends Equatable {
  final String id;
  final String groupId;
  final String description;
  final double amount;
  final String paidBy; // User ID who paid
  final DateTime date;
  final Map<String, double> split; // User ID -> Amount owed
  final String? imageUrl; // Receipt image
  final String createdBy; // User ID who added the expense

  const Expense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.date,
    required this.split,
    required this.createdBy,
    this.imageUrl,
  });

  @override
  List<Object?> get props => [
        id,
        groupId,
        description,
        amount,
        paidBy,
        date,
        split,
        imageUrl,
        createdBy,
      ];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'description': description,
      'amount': amount,
      'paidBy': paidBy,
      'date': date.millisecondsSinceEpoch,
      'split': jsonEncode(split),
      'imageURL': imageUrl,
      'createdBy': createdBy,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      groupId: map['groupId'] as String,
      description: map['description'] as String,
      amount: (map['amount'] as num).toDouble(),
      paidBy: map['paidBy'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      split: map['split'] is String
          ? Map<String, double>.from(jsonDecode(map['split'] as String))
          : Map<String, double>.from(map['split'] ?? {}),
      imageUrl: map['imageURL'] as String?,
      createdBy: map['createdBy'] as String,
    );
  }
}
