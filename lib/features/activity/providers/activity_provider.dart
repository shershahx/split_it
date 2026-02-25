import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/expense.dart';
import '../../expenses/providers/expenses_provider.dart';

/// Provider for fetching all expenses across all groups for the current user
final allExpensesProvider = FutureProvider<List<Expense>>((ref) async {
  return ref.watch(allUserExpensesProvider.future);
});
