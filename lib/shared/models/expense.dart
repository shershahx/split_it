// lib/shared/models/expense.dart
import 'dart:convert';
import 'package:equatable/equatable.dart';

import '../../core/utils/money.dart';

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
  final String currency;

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
    this.currency = 'USD',
  });

  /// Cent-conserving equal split for the app's two-decimal currencies.
  /// Remaining cents go to ascending member IDs, independent of input order.
  static Map<String, double> splitEqually({
    required double amount,
    required List<String> memberIds,
  }) {
    return Money.splitEqually(
      amount,
      memberIds,
    ).map((id, units) => MapEntry(id, Money.fromMinorUnits(units)));
  }

  /// Validated calculation view; does not modify persisted legacy shares.
  Map<String, int> get splitInMinorUnits => Money.allocateShares(amount, split);

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
        currency,
      ];

  /// List queries intentionally omit splits. Only getExpenseById loads a
  /// complete allocation; never calculate a group balance from a list page.
  factory Expense.fromSupabase(Map<String, dynamic> row) {
    final group = row['groups'] as Map<String, dynamic>?;
    final splits = (row['expense_splits'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    return Expense(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      description: row['description'] as String,
      amount: Money.fromMinorUnits(row['amount_minor'] as int),
      paidBy: row['paid_by'] as String,
      date: DateTime.parse(row['expense_date'] as String).toLocal(),
      createdBy: row['created_by'] as String,
      currency: group!['currency'] as String,
      imageUrl: row['receipt_path'] as String?,
      split: Map.unmodifiable({
        for (final split in splits)
          split['user_id'] as String:
              Money.fromMinorUnits(split['amount_minor'] as int),
      }),
    );
  }

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
