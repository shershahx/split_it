// lib/core/utils/balance_calculator.dart

import '../../shared/models/expense.dart';
import '../../shared/models/settlement.dart';

/// Represents a net balance between two users.
class UserBalance {
  final String userId;
  final double amount; // positive = they owe you, negative = you owe them

  const UserBalance({required this.userId, required this.amount});
}

/// Represents a simplified debt from one user to another.
class SimplifiedDebt {
  final String from; // debtor
  final String to; // creditor
  final double amount;

  const SimplifiedDebt({
    required this.from,
    required this.to,
    required this.amount,
  });
}

class BalanceCalculator {
  /// Calculate net balances for a specific user within a group,
  /// given a list of expenses and settlements.
  ///
  /// Returns a map of other userId -> net amount.
  /// Positive means the other user owes [currentUserId].
  /// Negative means [currentUserId] owes the other user.
  static Map<String, double> calculateNetBalances({
    required String currentUserId,
    required List<Expense> expenses,
    required List<Settlement> settlements,
  }) {
    final balances = <String, double>{};

    for (final expense in expenses) {
      final paidBy = expense.paidBy;
      final split = expense.split;

      for (final entry in split.entries) {
        final owerId = entry.key;
        final owedAmount = entry.value;

        if (owerId == paidBy) continue; // No self-debt

        if (paidBy == currentUserId) {
          // Current user paid, owerId owes them
          balances[owerId] = (balances[owerId] ?? 0) + owedAmount;
        } else if (owerId == currentUserId) {
          // Current user owes paidBy
          balances[paidBy] = (balances[paidBy] ?? 0) - owedAmount;
        }
        // If neither involves current user, skip
      }
    }

    // Apply settlements
    for (final settlement in settlements) {
      if (settlement.paidBy == currentUserId) {
        // Current user paid someone — reduces what they owe (or increases what they're owed)
        balances[settlement.paidTo] =
            (balances[settlement.paidTo] ?? 0) + settlement.amount;
      } else if (settlement.paidTo == currentUserId) {
        // Someone paid current user — reduces what that person owes
        balances[settlement.paidBy] =
            (balances[settlement.paidBy] ?? 0) - settlement.amount;
      }
    }

    // Remove zero balances
    balances.removeWhere((_, v) => v.abs() < 0.01);

    return balances;
  }

  /// Calculate simplified debts for a group.
  /// This uses a greedy algorithm to minimize transactions.
  ///
  /// Returns a list of simplified debts.
  static List<SimplifiedDebt> simplifyDebts({
    required List<Expense> expenses,
    required List<Settlement> settlements,
    required List<String> memberIds,
  }) {
    // Step 1: Calculate net balance for each member
    final netBalance = <String, double>{};
    for (final memberId in memberIds) {
      netBalance[memberId] = 0.0;
    }

    // Process expenses
    for (final expense in expenses) {
      final paidBy = expense.paidBy;
      final split = expense.split;

      for (final entry in split.entries) {
        final owerId = entry.key;
        final owedAmount = entry.value;

        if (owerId == paidBy) continue;

        // paidBy is owed money (positive), owerId owes money (negative)
        netBalance[paidBy] = (netBalance[paidBy] ?? 0) + owedAmount;
        netBalance[owerId] = (netBalance[owerId] ?? 0) - owedAmount;
      }
    }

    // Process settlements
    for (final settlement in settlements) {
      netBalance[settlement.paidBy] =
          (netBalance[settlement.paidBy] ?? 0) - settlement.amount;
      netBalance[settlement.paidTo] =
          (netBalance[settlement.paidTo] ?? 0) + settlement.amount;
    }

    // Step 2: Separate creditors (positive balance) and debtors (negative balance)
    final creditors = <MapEntry<String, double>>[];
    final debtors = <MapEntry<String, double>>[];

    for (final entry in netBalance.entries) {
      if (entry.value > 0.01) {
        creditors.add(entry);
      } else if (entry.value < -0.01) {
        debtors.add(MapEntry(entry.key, -entry.value)); // store as positive
      }
    }

    // Sort descending by amount for greedy matching
    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => b.value.compareTo(a.value));

    // Step 3: Greedy matching
    final debts = <SimplifiedDebt>[];
    final creditAmounts = {for (var c in creditors) c.key: c.value};
    final debtAmounts = {for (var d in debtors) d.key: d.value};

    for (final creditorId in creditAmounts.keys.toList()) {
      for (final debtorId in debtAmounts.keys.toList()) {
        if ((creditAmounts[creditorId] ?? 0) < 0.01) break;
        if ((debtAmounts[debtorId] ?? 0) < 0.01) continue;

        final amount = (creditAmounts[creditorId]! < debtAmounts[debtorId]!)
            ? creditAmounts[creditorId]!
            : debtAmounts[debtorId]!;

        debts.add(SimplifiedDebt(
          from: debtorId,
          to: creditorId,
          amount: double.parse(amount.toStringAsFixed(2)),
        ));

        creditAmounts[creditorId] = creditAmounts[creditorId]! - amount;
        debtAmounts[debtorId] = debtAmounts[debtorId]! - amount;
      }
    }

    return debts;
  }

  /// Calculate the total balance for a user across all provided expenses/settlements.
  /// Positive = net owed to user, Negative = net user owes.
  static double totalBalance({
    required String currentUserId,
    required List<Expense> expenses,
    required List<Settlement> settlements,
  }) {
    final balances = calculateNetBalances(
      currentUserId: currentUserId,
      expenses: expenses,
      settlements: settlements,
    );
    return balances.values.fold(0.0, (sum, v) => sum + v);
  }
}
