import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/expense.dart';
import '../../auth/providers/auth_provider.dart';
<<<<<<< HEAD
import '../../groups/providers/groups_provider.dart';
import '../data/expenses_repository.dart';

final expensesProvider =
    FutureProvider.family<List<Expense>, String>((ref, groupId) async {
  if (ref.watch(currentUserProvider.select((user) => user?.uid)) == null) {
    return [];
  }
  return ref.watch(expensesRepositoryProvider).getExpenses(groupId);
});

class ExpensesNotifier extends StateNotifier<AsyncValue<void>> {
  ExpensesNotifier(this._repository, {this.onChanged})
      : super(const AsyncValue.data(null));

  final ExpensesRepository _repository;
  final void Function(Expense expense)? onChanged;

  Future<void> _mutate(Expense expense, Future<void> Function() action) async {
    if (state.isLoading)
      throw StateError('An expense update is already in progress');
    state = const AsyncValue.loading();
    try {
      await action();
      if (!mounted) return;
      onChanged?.call(expense);
      state = const AsyncValue.data(null);
    } catch (error, stack) {
      if (mounted) state = AsyncValue.error(error, stack);
      rethrow;
    }
  }

  Future<void> saveExpense(Expense expense) =>
      _mutate(expense, () => _repository.saveExpense(expense));

  Future<void> deleteExpense(Expense expense) =>
      _mutate(expense, () => _repository.deleteExpense(expense));
}

final expensesNotifierProvider =
    StateNotifierProvider<ExpensesNotifier, AsyncValue<void>>((ref) {
  ref.watch(currentUserProvider.select((user) => user?.uid));
  return ExpensesNotifier(ref.watch(expensesRepositoryProvider),
      onChanged: (expense) {
    ref.invalidate(expensesProvider(expense.groupId));
    ref.invalidate(singleExpenseProvider(expense.id));
    ref.invalidate(allUserExpensesProvider);
  });
});

final singleExpenseProvider =
    FutureProvider.family<Expense?, String>((ref, expenseId) async {
  if (ref.watch(currentUserProvider.select((user) => user?.uid)) == null) {
    return null;
  }
  return ref.watch(expensesRepositoryProvider).getExpenseById(expenseId);
});

final allUserExpensesProvider = FutureProvider<List<Expense>>((ref) async {
  if (ref.watch(currentUserProvider.select((user) => user?.uid)) == null) {
    return [];
  }
  var active = true;
  ref.onDispose(() => active = false);
  final groups = await ref.watch(groupsProvider.future);
  if (!active) return [];
  final lists = await Future.wait([
    for (final group in groups) ref.watch(expensesProvider(group.id).future),
  ]);
  final expenses = lists.expand((list) => list).toList();
  expenses.sort((a, b) => b.date.compareTo(a.date));
  return expenses;
=======
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
    FutureProvider.autoDispose.family<Expense?, String>((ref, expenseId) async {
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

// Activity/friend history requires a separate server-paginated query; do not
// fetch every group or treat the first expense page as all-time activity.
final allUserExpensesProvider =
    FutureProvider.autoDispose<List<Expense>>((ref) async {
  final userId = ref.watch(currentUserProvider.select((user) => user?.uid));
  if (userId == null) return [];
  throw UnsupportedError('Cross-group expense activity is not connected yet.');
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
});
