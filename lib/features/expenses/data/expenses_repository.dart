import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

<<<<<<< HEAD
import '../../../core/services/cloud_db_service.dart';
=======
import '../../../core/services/financial_error.dart';
import '../../../core/utils/money.dart';
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
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
<<<<<<< HEAD

  final SupabaseClient _client;

  Expense _fromRow(Map<String, dynamic> row) {
    final amount = row['amount_minor'] as num;
    final splitRows = row['expense_splits'] as List;
    final majorAmount = CloudDbService.fromMinorUnits(amount);
    var remaining = amount.toInt();
    final split = <String, double>{};
    for (final entry in splitRows) {
      final userId = entry['user_id'] as String;
      final minor = entry['amount_minor'] as num;
      final major = CloudDbService.fromMinorUnits(minor);
      if (minor < 0 || minor > remaining || split.containsKey(userId)) {
        throw const FormatException('Invalid or incomplete expense splits');
      }
      remaining -= minor.toInt();
      split[userId] = major;
    }
    if (amount <= 0 || split.isEmpty || remaining != 0) {
      throw const FormatException('Invalid or incomplete expense splits');
    }
    return Expense(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      description: row['description'] as String,
      amount: majorAmount,
      paidBy: row['paid_by'] as String,
      date: DateTime.parse(row['expense_date'] as String),
      split: split,
      imageUrl: row['receipt_path'] as String?,
      createdBy: row['created_by'] as String,
    );
  }

  Future<List<Expense>> getExpenses(String groupId) async {
    // The view aggregates splits inside SQL, outside nested-resource row caps.
    final rows = await CloudDbService.readAll(
        () => _client.from('expense_records').select().eq('group_id', groupId));
    final expenses = rows.map(_fromRow).toList();
    expenses.sort((a, b) {
      final date = b.date.compareTo(a.date);
      return date != 0 ? date : b.id.compareTo(a.id);
    });
    return expenses;
  }

  /// Replaces the expense and all splits in one database transaction.
  Future<void> saveExpense(Expense expense) async {
    final amount = CloudDbService.toMinorUnits(expense.amount);
    final splits = [
      for (final entry in expense.split.entries)
        {
          'user_id': entry.key,
          'amount_minor': CloudDbService.toMinorUnits(entry.value),
        },
    ];
    final total = splits.fold<int>(
      0,
      (sum, split) => sum + (split['amount_minor'] as int),
    );
    if (amount <= 0 ||
        splits.isEmpty ||
        splits.any((split) => (split['amount_minor'] as int) < 0) ||
        total != amount) {
      throw ArgumentError('Nonnegative splits must sum to the positive amount');
    }
    await _client.rpc('save_expense', params: {
      'p_id': expense.id,
      'p_group_id': expense.groupId,
      'p_description': expense.description,
      'p_amount_minor': amount,
      'p_paid_by': expense.paidBy,
      'p_expense_date': expense.date.toUtc().toIso8601String(),
      'p_receipt_path': expense.imageUrl,
      'p_created_by': expense.createdBy,
      'p_splits': splits,
    });
  }

  Future<void> deleteExpense(Expense expense) async {
    await _client.from('expenses').delete().eq('id', expense.id);
  }

  Future<Expense?> getExpenseById(String expenseId) async {
    final row = await _client
        .from('expense_records')
        .select()
        .eq('id', expenseId)
        .maybeSingle();
    return row == null ? null : _fromRow(row);
=======
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
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
  }
}
