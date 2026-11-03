// lib/shared/models/settlement.dart
import 'package:equatable/equatable.dart';
import '../../core/utils/money.dart';

class Settlement extends Equatable {
  final String id;
  final String groupId;
  final String paidBy; // User who paid (settled debt)
  final String paidTo; // User who received payment
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

  /// Supabase stores exact integer cents; keep the legacy map API unchanged.
  factory Settlement.fromSupabaseRow(Map<String, dynamic> row) {
    final minor = row['amount_minor'] as int;
    if (minor <= 0) throw const FormatException('Invalid settlement amount');
    return Settlement(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      paidBy: row['paid_by'] as String,
      paidTo: row['paid_to'] as String,
      amount: Money.fromMinorUnits(minor),
      date: DateTime.parse(row['settled_at'] as String).toLocal(),
      note: row['note'] as String?,
    );
  }
}
