// lib/features/expenses/providers/expenses_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/expense.dart';
import '../../auth/providers/auth_provider.dart';
import '../../groups/data/groups_repository.dart';
import '../data/expenses_repository.dart';

// Provider for expenses list by group
final expensesProvider = FutureProvider.family<List<Expense>, String>((ref, groupId) async {
  final repository = ref.read(expensesRepositoryProvider);
  return await repository.getExpenses(groupId);
});

// State notifier for creating/updating/deleting expenses
class ExpensesNotifier extends StateNotifier<AsyncValue<void>> {
  final ExpensesRepository _repository;

  ExpensesNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<void> saveExpense(Expense expense) async {
    state = const AsyncValue.loading();
    try {
      await _repository.saveExpense(expense);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteExpense(Expense expense) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteExpense(expense);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final expensesNotifierProvider = StateNotifierProvider<ExpensesNotifier, AsyncValue<void>>((ref) {
  return ExpensesNotifier(ref.read(expensesRepositoryProvider));
});

// Provider for a single expense by id (queries Cloud DB directly)
final singleExpenseProvider = FutureProvider.family<Expense?, String>((ref, expenseId) async {
  final repository = ref.read(expensesRepositoryProvider);
  return repository.getExpenseById(expenseId);
});

// Provider for ALL expenses across ALL groups for the current user (used by Activity feed)
final allUserExpensesProvider = FutureProvider<List<Expense>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final groupsRepo = ref.read(groupsRepositoryProvider);
  final expensesRepo = ref.read(expensesRepositoryProvider);

  final groups = await groupsRepo.getGroups(user.uid);
  final allExpenses = <Expense>[];

  for (final group in groups) {
    final expenses = await expensesRepo.getExpenses(group.id);
    allExpenses.addAll(expenses);
  }

  allExpenses.sort((a, b) => b.date.compareTo(a.date));
  return allExpenses;
});
