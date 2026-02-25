// lib/features/expenses/data/expenses_repository.dart
import 'package:agconnect_clouddb/agconnect_clouddb.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/cloud_db_service.dart';
import '../../../shared/models/expense.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepository(ref.read(cloudDbServiceProvider));
});

class ExpensesRepository {
  final CloudDbService _cloudDbService;
  final String _objectTypeName = "Expense"; // Must match Cloud DB Object Type name

  ExpensesRepository(this._cloudDbService);

  // Fetch expenses for a group
  Future<List<Expense>> getExpenses(String groupId) async {
    try {
      final query = AGConnectCloudDBQuery(_objectTypeName);
      query.equalTo("groupId", groupId);
      query.orderBy("date", ascending: false);
      
      final result = await _cloudDbService.executeQuery(query);
      return result.map((map) => Expense.fromMap(map)).toList();
    } catch (e) {
      throw Exception('Failed to fetch expenses: $e');
    }
  }

  // Create or update an expense
  Future<void> saveExpense(Expense expense) async {
    try {
      await _cloudDbService.upsertObject(_objectTypeName, [expense.toMap()]);
    } catch (e) {
      throw Exception('Failed to save expense: $e');
    }
  }

  // Delete an expense
  Future<void> deleteExpense(Expense expense) async {
    try {
      await _cloudDbService.deleteObject(_objectTypeName, [expense.toMap()]);
    } catch (e) {
      throw Exception('Failed to delete expense: $e');
    }
  }

  // Get a single expense by ID
  Future<Expense?> getExpenseById(String expenseId) async {
    try {
      final query = AGConnectCloudDBQuery(_objectTypeName);
      query.equalTo('id', expenseId);
      final result = await _cloudDbService.executeQuery(query);
      if (result.isEmpty) return null;
      return Expense.fromMap(result.first);
    } catch (e) {
      throw Exception('Failed to fetch expense: $e');
    }
  }
}
