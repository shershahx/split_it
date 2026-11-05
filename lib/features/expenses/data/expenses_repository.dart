import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/financial_error.dart';
import '../../../core/utils/money.dart';
import '../../../shared/models/expense.dart';
import '../../auth/providers/auth_provider.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepository(ref.watch(supabaseClientProvider));
});

class ExpensePage {
  final List<Expense> expenses;
  final bool hasNext;
  const ExpensePage({required this.expenses, required this.hasNext});
}

class ExpensesRepository {
  ExpensesRepository(this._client);
  final SupabaseClient _client;
  static const pageSize = 20;
  static const _columns =
      'id,group_id,description,amount_minor,paid_by,expense_date,receipt_path,'
      'created_by,groups(currency)';

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

  Future<ExpensePage> getExpenses(String groupId, {int page = 0}) async {
    final userId = _userId;
    if (page < 0) throw ArgumentError.value(page, 'page');
    final rows = await _client
        .from('expenses')
        .select(_columns)
        .eq('group_id', groupId)
        .order('expense_date', ascending: false)
        .order('id', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize);
    _checkAccount(userId);
    return ExpensePage(
      expenses: List.unmodifiable(
        rows.take(pageSize).map(Expense.fromSupabase),
      ),
      hasNext: rows.length > pageSize,
    );
  }

  /// One RPC persists both the expense and allocations, never separate writes.
  /// The client UUID is reused for an unchanged retry after an uncertain result.
  Future<void> saveExpense(Expense expense) async {
    final userId = _userId;
    if (expense.createdBy != userId) {
      throw const FinancialFailure('You can only save an expense as yourself.');
    }
    final amount = Money.toMinorUnits(expense.amount);
    if (amount <= 0) {
      throw const FinancialFailure('Enter an amount greater than zero.');
    }
    if (Money.fromMinorUnits(amount) != expense.amount) {
      throw const FinancialFailure('Use at most two decimal places.');
    }
    final description = expense.description.trim();
    if (description.isEmpty || description.length > 200) {
      throw const FinancialFailure('Use a description of 1–200 characters.');
    }
    final shares = expense.splitInMinorUnits;
    await _client.rpc('create_expense', params: {
      'expense_id': expense.id,
      'target_group_id': expense.groupId,
      'expense_description': description,
      'total_minor': amount,
      'payer_id': expense.paidBy,
      'spent_at': expense.date.toUtc().toIso8601String(),
      'splits': [
        for (final share in shares.entries)
          {'user_id': share.key, 'amount_minor': share.value},
      ],
    });
    _checkAccount(userId);
  }

  Future<void> deleteExpense(Expense expense) async {
    final userId = _userId;
    await _client
        .rpc('delete_expense', params: {'target_expense_id': expense.id});
    _checkAccount(userId);
  }

  Future<Expense?> getExpenseById(String expenseId) async {
    final userId = _userId;
    final row = await _client
        .from('expenses')
        .select('$_columns,split_count:expense_splits(count)')
        .eq('id', expenseId)
        .maybeSingle();
    _checkAccount(userId);
    if (row == null) return null;
    final countRows = (row['split_count'] as List).cast<Map<String, dynamic>>();
    final expected = countRows.isEmpty ? 0 : countRows.single['count'] as int;
    final splits = <Map<String, dynamic>>[];
    while (splits.length < expected) {
      final offset = splits.length;
      final batch = await _client
          .from('expense_splits')
          .select('user_id,amount_minor')
          .eq('expense_id', expenseId)
          .order('user_id', ascending: true)
          .range(offset, offset + 99);
      _checkAccount(userId);
      if (batch.isEmpty) break;
      splits.addAll(batch);
    }
    if (splits.length != expected ||
        splits.map((split) => split['user_id']).toSet().length != expected) {
      throw const FinancialFailure('Expense changed. Please refresh.');
    }
    final expense = Expense.fromSupabase({...row, 'expense_splits': splits});
    // Legacy/externally modified records must not silently show invalid totals.
    expense.splitInMinorUnits;
    return expense;
  }

  /// All-history totals are computed by PostgreSQL, not a truncated UI page.
  Future<Map<String, int>> getGroupBalances(String groupId) async {
    final userId = _userId;
    final result = await _client.rpc(
      'get_group_balances',
      params: {'target_group_id': groupId},
    ) as Map<String, dynamic>;
    _checkAccount(userId);
    final balances = <String, int>{};
    for (final row
        in (result['balances'] as List).cast<Map<String, dynamic>>()) {
      final id = row['user_id'] as String;
      final units = row['balance_minor'] as int;
      Money.formatMinorUnits(units); // Validate native/web-safe range.
      if (balances.containsKey(id)) {
        throw const FinancialFailure('Could not verify the group balances.');
      }
      balances[id] = units;
    }
    final total = balances.values
        .fold<BigInt>(BigInt.zero, (sum, value) => sum + BigInt.from(value));
    if (total != BigInt.zero) {
      throw const FinancialFailure('Could not verify the group balances.');
    }
    return Map.unmodifiable(balances);
  }
}
