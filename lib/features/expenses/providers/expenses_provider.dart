import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/expense.dart';
import '../../auth/providers/auth_provider.dart';
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
});

class ExpensesNotifier extends StateNotifier<AsyncValue<void>> {
  ExpensesNotifier(this._repository) : super(const AsyncValue.data(null));

  final ExpensesRepository _repository;

  Future<void> saveExpense(Expense expense) async {
    if (state.isLoading) return;
    state = const AsyncValue.loading();
    try {
      await _repository.saveExpense(expense);
      if (!mounted) return;
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
  return ExpensesNotifier(ref.watch(expensesRepositoryProvider));
});
