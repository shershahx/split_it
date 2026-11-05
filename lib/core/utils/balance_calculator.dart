import '../../shared/models/expense.dart';
import '../../shared/models/settlement.dart';
import 'money.dart';

/// Positive = they owe you; negative = you owe them.
class UserBalance {
  final String userId;
  final double amount;

  const UserBalance({required this.userId, required this.amount});
}

class SimplifiedDebt {
  final String from;
  final String to;
  final double amount;

  const SimplifiedDebt({
    required this.from,
    required this.to,
    required this.amount,
  });
}

/// Combined and intermediate balances support up to
/// [Money.maxAggregateMinorUnits] cents in either direction. Records retain
/// [Money.maxMinorUnits] as their individual limit. Reports beyond the aggregate
/// limit fail explicitly rather than returning imprecise double-valued totals.
class BalanceCalculator {
  /// Other user ID -> net amount in the app's two-decimal currency.
  /// Positive means they owe [currentUserId]; negative means the user owes them.
  /// Invalid records throw [ArgumentError], including records unrelated to the
  /// current user. Self-payments have no effect, but are still validated.
  static Map<String, double> calculateNetBalances({
    required String currentUserId,
    required List<Expense> expenses,
    required List<Settlement> settlements,
  }) {
    return _netBalances(
      currentUserId,
      expenses,
      settlements,
    ).map((id, units) => MapEntry(id, Money.fromMinorUnits(units)));
  }

  static Map<String, int> _netBalances(
    String currentUserId,
    List<Expense> expenses,
    List<Settlement> settlements,
  ) {
    Money.validateUserId(currentUserId);
    final balances = <String, int>{};
    _forEachTransfer(expenses, settlements, (debtor, creditor, units) {
      if (creditor == currentUserId) {
        balances[debtor] = Money.add(balances[debtor] ?? 0, units);
      } else if (debtor == currentUserId) {
        balances[creditor] = Money.add(balances[creditor] ?? 0, -units);
      }
    });
    balances.removeWhere((_, units) => units == 0);
    return balances;
  }

  /// Deterministic greedy matching of group net balances.
  ///
  /// Largest balances are matched first, with ascending user ID breaking ties.
  /// This reduces transfers but does not guarantee the mathematical minimum.
  /// Historical participants absent from [memberIds] are retained. An empty
  /// member list is valid; blank or duplicate member IDs are not.
  static List<SimplifiedDebt> simplifyDebts({
    required List<Expense> expenses,
    required List<Settlement> settlements,
    required List<String> memberIds,
  }) {
    final net = {for (final id in Money.sortedMemberIds(memberIds)) id: 0};
    _forEachTransfer(expenses, settlements, (debtor, creditor, units) {
      net[creditor] = Money.add(net[creditor] ?? 0, units);
      net[debtor] = Money.add(net[debtor] ?? 0, -units);
    });
    final creditors = net.entries.where((entry) => entry.value > 0).toList();
    final debtors = net.entries
        .where((entry) => entry.value < 0)
        .map((entry) => MapEntry(entry.key, -entry.value))
        .toList();
    int compare(MapEntry<String, int> a, MapEntry<String, int> b) {
      final byAmount = b.value.compareTo(a.value);
      return byAmount != 0 ? byAmount : a.key.compareTo(b.key);
    }

    creditors.sort(compare);
    debtors.sort(compare);
    final debts = <SimplifiedDebt>[];
    var c = 0;
    var d = 0;
    var credit = creditors.isEmpty ? 0 : creditors.first.value;
    var debt = debtors.isEmpty ? 0 : debtors.first.value;
    while (c < creditors.length && d < debtors.length) {
      final units = credit < debt ? credit : debt;
      debts.add(
        SimplifiedDebt(
          from: debtors[d].key,
          to: creditors[c].key,
          amount: Money.fromMinorUnits(units),
        ),
      );
      credit -= units;
      debt -= units;
      if (credit == 0 && ++c < creditors.length) {
        credit = creditors[c].value;
      }
      if (debt == 0 && ++d < debtors.length) {
        debt = debtors[d].value;
      }
    }
    return debts;
  }

  /// Positive = net owed to user; negative = net user owes.
  static double totalBalance({
    required String currentUserId,
    required List<Expense> expenses,
    required List<Settlement> settlements,
  }) {
    final balances = _netBalances(currentUserId, expenses, settlements);
    final units = balances.values.fold<int>(0, Money.add);
    return Money.fromMinorUnits(units);
  }

  /// A transfer represents outstanding debt, not an actual payment.
  /// Payments reverse that direction, reducing (or reversing) the debt.
  /// Keeping this rule shared makes bilateral and group balances agree.
  static void _forEachTransfer(
    List<Expense> expenses,
    List<Settlement> settlements,
    void Function(String debtor, String creditor, int units) visit,
  ) {
    for (final expense in expenses) {
      Money.validateUserId(expense.paidBy);
      for (final share in expense.splitInMinorUnits.entries) {
        if (share.key != expense.paidBy && share.value != 0) {
          visit(share.key, expense.paidBy, share.value);
        }
      }
    }
    for (final settlement in settlements) {
      Money.validateUserId(settlement.paidBy);
      Money.validateUserId(settlement.paidTo);
      final units = Money.toMinorUnits(settlement.amount);
      if (settlement.paidBy != settlement.paidTo && units != 0) {
        visit(settlement.paidTo, settlement.paidBy, units);
      }
    }
  }
}
