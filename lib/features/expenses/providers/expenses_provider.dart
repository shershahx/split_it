import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/expense.dart';
import '../../auth/providers/auth_provider.dart';
import '../../groups/providers/groups_provider.dart';
import '../data/expenses_repository.dart';

final expensePageIndexProvider =
    StateProvider.autoDispose.family<int, String>((ref, groupId) {
  ref.watch(currentUserProvider.select((user) => user?.uid));
  return 0;
});

final expensePageProvider = FutureProvider.autoDispose
    .family<ExpensePage, String>((ref, groupId) async {
  final userId = ref.watch(currentUserProvider.select((user) => user?.uid));
  final page = ref.watch(expensePageIndexProvider(groupId));
  if (userId == null) return const ExpensePage(expenses: [], hasNext: false);
  return ref.watch(expensesRepositoryProvider).getExpenses(groupId, page: page);
});

// Compatibility for list consumers only, never a complete financial ledger.
final expensesProvider = FutureProvider.autoDispose
    .family<List<Expense>, String>((ref, groupId) async {
  return (await ref.watch(expensePageProvider(groupId).future)).expenses;
});

final singleExpenseProvider =
    FutureProvider.family<Expense?, String>((ref, expenseId) async {
  final userId = ref.watch(currentUserProvider.select((user) => user?.uid));
  if (userId == null) return null;
  return ref.watch(expensesRepositoryProvider).getExpenseById(expenseId);
});

final groupBalancesProvider = FutureProvider.autoDispose
    .family<Map<String, int>, String>((ref, groupId) async {
  final userId = ref.watch(currentUserProvider.select((user) => user?.uid));
  if (userId == null) return {};
  return ref.watch(expensesRepositoryProvider).getGroupBalances(groupId);
});

// Activity/friend history aggregates current expenses across the user's groups.
final allUserExpensesProvider =
    FutureProvider.autoDispose<List<Expense>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  var active = true;
  ref.onDispose(() => active = false);
  final page = await ref.watch(groupsProvider.future);
  if (!active || ref.read(currentUserProvider)?.uid != user.uid) return [];
  final lists = await Future.wait([
    for (final group in page.groups)
      ref.watch(expensesProvider(group.id).future),
  ]);
  if (!active || ref.read(currentUserProvider)?.uid != user.uid) return [];
  final expenses = lists.expand((list) => list).toList();
  expenses.sort((a, b) => b.date.compareTo(a.date));
  return expenses;
});

class ExpensesNotifier extends StateNotifier<AsyncValue<void>> {
  ExpensesNotifier(this._repository, [void Function(Expense)? onChanged])
      : _onChanged = onChanged,
        super(const AsyncValue.data(null));

  final ExpensesRepository _repository;
  final void Function(Expense)? _onChanged;

  Future<void> saveExpense(Expense expense) async {
    if (state.isLoading) return;
    state = const AsyncValue.loading();
    try {
      await _repository.saveExpense(expense);
      if (!mounted) return;
      _onChanged?.call(expense);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteExpense(Expense expense) async {
    if (state.isLoading) return;
    state = const AsyncValue.loading();
    try {
      await _repository.deleteExpense(expense);
      if (!mounted) return;
      _onChanged?.call(expense);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final expensesNotifierProvider =
    StateNotifierProvider.autoDispose<ExpensesNotifier, AsyncValue<void>>(
        (ref) {
  ref.watch(currentUserProvider.select((user) => user?.uid));
  return ExpensesNotifier(ref.watch(expensesRepositoryProvider), (expense) {
    ref.invalidate(expensesProvider(expense.groupId));
    ref.invalidate(expensePageProvider(expense.groupId));
    ref.invalidate(singleExpenseProvider(expense.id));
    ref.invalidate(allUserExpensesProvider);
  });
});
