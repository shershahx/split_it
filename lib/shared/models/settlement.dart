// lib/shared/models/settlement.dart
import 'package:equatable/equatable.dart';

class Settlement extends Equatable {
  final String id;
  final String groupId;
  final String paidBy;      // User who paid (settled debt)
  final String paidTo;      // User who received payment
  final double amount;
  final DateTime date;
  final String? note;

  const Settlement({
    required this.id,
    required this.groupId,
    required this.paidBy,
    required this.paidTo,
    required this.amount,
    required this.date,
    this.note,
  });

  @override
  List<Object?> get props => [id, groupId, paidBy, paidTo, amount, date, note];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'paidBy': paidBy,
      'paidTo': paidTo,
      'amount': amount,
      'date': date.millisecondsSinceEpoch,
      'note': note,
    };
  }

  factory Settlement.fromMap(Map<String, dynamic> map) {
    return Settlement(
      id: map['id'] as String,
      groupId: map['groupId'] as String,
      paidBy: map['paidBy'] as String,
      paidTo: map['paidTo'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      note: map['note'] as String?,
    );
  }
}
