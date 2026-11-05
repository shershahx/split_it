import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/financial_error.dart';
import '../../../core/utils/money.dart';
import '../../../shared/models/settlement.dart';
import '../../auth/providers/auth_provider.dart';

final settlementsRepositoryProvider =
    Provider.autoDispose<SettlementsRepository>((ref) {
  return SettlementsRepository(ref.watch(supabaseClientProvider));
});

class SettlementPage {
  final List<Settlement> settlements;
  final bool hasNext;

  const SettlementPage({required this.settlements, required this.hasNext});
}

class SettlementsRepository {
  SettlementsRepository(this._client);

  final SupabaseClient _client;
  static const pageSize = 20;
  static const _columns =
      'id,group_id,paid_by,paid_to,amount_minor,settled_at,note,created_by,created_at';
  static final _uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const FinancialFailure('Please sign in again.');
    return id;
  }

  void _checkAccount(String userId) {
    if (_client.auth.currentUser?.id != userId) {
      throw const FinancialFailure('Your account changed. Please try again.');
    }
  }

  void _checkId(String id) {
    if (!_uuid.hasMatch(id)) {
      throw const FinancialFailure('This record has an invalid identifier.');
    }
    if (_client.auth.currentUser?.id != settlement.paidBy) {
      throw StateError('Only the current user can record their own payment');
    }
    await _client.rpc('save_settlement', params: {
      'p_id': settlement.id,
      'p_group_id': settlement.groupId,
      'p_paid_by': settlement.paidBy,
      'p_paid_to': settlement.paidTo,
      'p_amount_minor': amount,
      'p_settled_at': settlement.date.toUtc().toIso8601String(),
      'p_note': settlement.note,
    });
  }

  /// Bounded history, not an input to financial balance calculations.
  Future<SettlementPage> getSettlementPage(String groupId,
      {int page = 0}) async {
    final userId = _userId;
    _checkId(groupId);
    if (page < 0) throw ArgumentError.value(page, 'page');
    final rows = await _client
        .from('settlements')
        .select(_columns)
        .eq('group_id', groupId)
        .order('settled_at', ascending: false)
        .order('id', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize);
    _checkAccount(userId);
    return SettlementPage(
      settlements: List.unmodifiable(
          rows.take(pageSize).map(Settlement.fromSupabaseRow)),
      hasNext: rows.length > pageSize,
    );
  }

  /// Compatibility preview only. Never downloads all settlement history.
  Future<List<Settlement>> getSettlements(String groupId) async =>
      (await getSettlementPage(groupId)).settlements;

  Future<Settlement?> getSettlementById(String settlementId) async {
    final userId = _userId;
    _checkId(settlementId);
    final row = await _client
        .from('settlements')
        .select(_columns)
        .eq('id', settlementId)
        .maybeSingle();
    _checkAccount(userId);
    return row == null ? null : Settlement.fromSupabaseRow(row);
  }

  /// Payer and creator are derived by the server from auth.uid(). This check
  /// catches stale account drafts locally; it is not a substitute for RLS.
  Future<void> saveSettlement(Settlement settlement) async {
    final userId = _userId;
    if (settlement.paidBy != userId) {
      throw const FinancialFailure('You can only record your own payments.');
    }
    for (final id in [
      settlement.id,
      settlement.groupId,
      settlement.paidBy,
      settlement.paidTo,
    ]) {
      _checkId(id);
    }
    if (settlement.paidTo == userId) {
      throw const FinancialFailure('Select another group member.');
    }
    int minor;
    try {
      minor = Money.toMinorUnits(settlement.amount);
      if (Money.fromMinorUnits(minor) != settlement.amount) {
        throw ArgumentError.value(settlement.amount, 'amount');
      }
    } on ArgumentError {
      throw const FinancialFailure(
          'Enter a valid amount with at most two decimal places.');
    }
    if (minor <= 0) {
      throw const FinancialFailure('Enter an amount greater than zero.');
    }
    if ((settlement.note?.runes.length ?? 0) > 300) {
      throw const FinancialFailure('Keep the note to 300 characters or fewer.');
    }
    await _client.rpc('record_settlement', params: {
      'settlement_id': settlement.id,
      'target_group_id': settlement.groupId,
      'recipient_id': settlement.paidTo,
      'total_minor': minor,
      'paid_at': settlement.date.toUtc().toIso8601String(),
      'settlement_note': settlement.note,
    });
    _checkAccount(userId);
  }

  Future<void> deleteSettlement(Settlement settlement) async {
    final userId = _userId;
    _checkId(settlement.id);
    await _client.rpc('delete_settlement', params: {
      'target_settlement_id': settlement.id,
    });
    _checkAccount(userId);
  }
}
