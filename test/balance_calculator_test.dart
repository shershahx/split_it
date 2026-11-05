import 'package:flutter_test/flutter_test.dart';
import 'package:split_it/core/utils/balance_calculator.dart';
import 'package:split_it/core/utils/money.dart';
import 'package:split_it/shared/models/expense.dart';
import 'package:split_it/shared/models/settlement.dart';

Expense expense({
  double amount = 10,
  String payer = 'a',
  Map<String, double>? split,
}) => Expense(
  id: 'e',
  groupId: 'g',
  description: 'Test',
  amount: amount,
  paidBy: payer,
  date: DateTime(2025),
  split: split ?? {'b': amount},
  createdBy: payer,
);

Settlement payment(double amount, {String from = 'b', String to = 'a'}) =>
    Settlement(
      id: 's',
      groupId: 'g',
      paidBy: from,
      paidTo: to,
      amount: amount,
      date: DateTime(2025),
    );

List<List<Object>> debtRows(List<SimplifiedDebt> debts) =>
    debts.map((d) => <Object>[d.from, d.to, d.amount]).toList();

void main() {
  group('settlement direction in every API', () {
    for (final paid in [0.0, 4.0, 10.0, 12.0]) {
      test('payment $paid reduces, clears or reverses the debt', () {
        final expenses = [expense()];
        final settlements = [payment(paid)];
        final remaining = 10 - paid;
        expect(
          BalanceCalculator.calculateNetBalances(
            currentUserId: 'a',
            expenses: expenses,
            settlements: settlements,
          ),
          remaining == 0 ? <String, double>{} : {'b': remaining},
        );
        expect(
          BalanceCalculator.calculateNetBalances(
            currentUserId: 'b',
            expenses: expenses,
            settlements: settlements,
          ),
          remaining == 0 ? <String, double>{} : {'a': -remaining},
        );
        expect(
          BalanceCalculator.totalBalance(
            currentUserId: 'a',
            expenses: expenses,
            settlements: settlements,
          ),
          remaining,
        );
        expect(
          debtRows(
            BalanceCalculator.simplifyDebts(
              expenses: expenses,
              settlements: settlements,
              memberIds: ['a', 'b'],
            ),
          ),
          remaining == 0
              ? <List<Object>>[]
              : [
                  remaining > 0
                      ? <Object>['b', 'a', remaining]
                      : <Object>['a', 'b', -remaining],
                ],
        );
      });
    }

    test('a payment in the opposite direction increases the debt', () {
      expect(
        debtRows(
          BalanceCalculator.simplifyDebts(
            expenses: [expense()],
            settlements: [payment(2, from: 'a', to: 'b')],
            memberIds: ['a', 'b'],
          ),
        ),
        [
          ['b', 'a', 12.0],
        ],
      );
    });

    test('settlement without an expense creates the reverse obligation', () {
      expect(
        debtRows(
          BalanceCalculator.simplifyDebts(
            expenses: [],
            settlements: [payment(0.01)],
            memberIds: [],
          ),
        ),
        [
          ['a', 'b', 0.01],
        ],
      );
    });
  });

  test('preserves exact one-cent debts and removes only exact zero', () {
    final expenses = [expense(amount: 0.03)];
    final settlements = [payment(0.02)];
    for (final user in ['a', 'b']) {
      final sign = user == 'a' ? 1 : -1;
      expect(
        BalanceCalculator.totalBalance(
          currentUserId: user,
          expenses: expenses,
          settlements: settlements,
        ),
        sign * 0.01,
      );
    }
    expect(
      debtRows(
        BalanceCalculator.simplifyDebts(
          expenses: expenses,
          settlements: settlements,
          memberIds: ['a', 'b'],
        ),
      ),
      [
        ['b', 'a', 0.01],
      ],
    );
  });

  test('fractional legacy shares conserve cents including the payer share', () {
    final expenses = [
      expense(amount: 1, split: {'c': 1 / 3, 'a': 1 / 3, 'b': 1 / 3}),
    ];
    expect(
      BalanceCalculator.calculateNetBalances(
        currentUserId: 'a',
        expenses: expenses,
        settlements: [],
      ),
      {'b': 0.33, 'c': 0.33},
    );
    expect(
      debtRows(
        BalanceCalculator.simplifyDebts(
          expenses: expenses,
          settlements: [],
          memberIds: ['c', 'a', 'b'],
        ),
      ),
      [
        ['b', 'a', 0.33],
        ['c', 'a', 0.33],
      ],
    );
  });

  test('integer accumulation avoids phantom cents in all APIs', () {
    final expenses = List.generate(1000, (_) => expense(amount: 0.01));
    final settlements = List.generate(999, (_) => payment(0.01));
    expect(
      BalanceCalculator.calculateNetBalances(
        currentUserId: 'a',
        expenses: expenses,
        settlements: settlements,
      ),
      {'b': 0.01},
    );
    expect(
      BalanceCalculator.totalBalance(
        currentUserId: 'a',
        expenses: [
          expense(amount: 0.1),
          expense(amount: 0.2, split: {'c': 0.2}),
        ],
        settlements: [],
      ),
      0.3,
    );
    expect(
      debtRows(
        BalanceCalculator.simplifyDebts(
          expenses: expenses,
          settlements: settlements,
          memberIds: ['a', 'b'],
        ),
      ),
      [
        ['b', 'a', 0.01],
      ],
    );
    expect(
      BalanceCalculator.totalBalance(
        currentUserId: 'a',
        expenses: expenses,
        settlements: [...settlements, payment(0.01)],
      ),
      0,
    );
  });

  test('ties and record/member ordering produce deterministic matching', () {
    final expenses = [
      expense(payer: 'c2', split: {'d2': 10}),
      expense(payer: 'c1', split: {'d1': 10}),
    ];
    final expected = [
      ['d1', 'c1', 10.0],
      ['d2', 'c2', 10.0],
    ];
    for (final records in [expenses, expenses.reversed.toList()]) {
      for (final members in [
        ['c2', 'd2', 'c1', 'd1'],
        ['d1', 'c1', 'd2', 'c2'],
        <String>[],
      ]) {
        expect(
          debtRows(
            BalanceCalculator.simplifyDebts(
              expenses: records,
              settlements: [],
              memberIds: members,
            ),
          ),
          expected,
        );
      }
    }
  });

  test('simplified debts conserve every participant net and fully settle', () {
    final expenses = [
      expense(
        amount: 10,
        split: Expense.splitEqually(
          amount: 10,
          memberIds: ['a', 'b', 'c', 'd'],
        ),
      ),
      expense(amount: 1.01, payer: 'c', split: {'a': 0.31, 'd': 0.7}),
      expense(amount: 0.02, payer: 'd', split: {'b': 0.02}),
    ];
    final settlements = [payment(0.91), payment(0.03, from: 'd', to: 'c')];
    final debts = BalanceCalculator.simplifyDebts(
      expenses: expenses,
      settlements: settlements,
      memberIds: ['a', 'b', 'c', 'd'],
    );
    var total = 0;
    for (final user in ['a', 'b', 'c', 'd']) {
      final original = Money.toMinorUnits(
        BalanceCalculator.totalBalance(
          currentUserId: user,
          expenses: expenses,
          settlements: settlements,
        ).abs(),
      );
      final signedOriginal =
          BalanceCalculator.totalBalance(
                currentUserId: user,
                expenses: expenses,
                settlements: settlements,
              ) <
              0
          ? -original
          : original;
      total += signedOriginal;
      final simplified = debts.fold<int>(0, (sum, debt) {
        final cents = Money.toMinorUnits(debt.amount);
        return sum +
            (debt.to == user ? cents : 0) -
            (debt.from == user ? cents : 0);
      });
      expect(simplified, signedOriginal);
    }
    expect(total, 0);
    expect(
      BalanceCalculator.simplifyDebts(
        expenses: expenses,
        settlements: [
          ...settlements,
          ...debts.map((d) => payment(d.amount, from: d.from, to: d.to)),
        ],
        memberIds: [],
      ),
      isEmpty,
    );
  });

  test('self expense shares and self payments never create self debt', () {
    expect(
      BalanceCalculator.calculateNetBalances(
        currentUserId: 'a',
        expenses: [
          expense(split: {'a': 10}),
        ],
        settlements: [payment(4, from: 'a', to: 'a')],
      ),
      isEmpty,
    );
    expect(
      BalanceCalculator.simplifyDebts(
        expenses: [
          expense(split: {'a': 10}),
        ],
        settlements: [payment(4, from: 'a', to: 'a')],
        memberIds: ['a'],
      ),
      isEmpty,
    );
  });

  group('invalid input', () {
    void expectRejected(List<Expense> expenses, List<Settlement> settlements) {
      expect(
        () => BalanceCalculator.calculateNetBalances(
          currentUserId: 'unrelated',
          expenses: expenses,
          settlements: settlements,
        ),
        throwsArgumentError,
      );
      expect(
        () => BalanceCalculator.totalBalance(
          currentUserId: 'unrelated',
          expenses: expenses,
          settlements: settlements,
        ),
        throwsArgumentError,
      );
      expect(
        () => BalanceCalculator.simplifyDebts(
          expenses: expenses,
          settlements: settlements,
          memberIds: [],
        ),
        throwsArgumentError,
      );
    }

    test('all APIs validate amounts even when unrelated to current user', () {
      for (final value in [-0.01, double.nan, double.infinity, 1e100]) {
        expectRejected([expense(amount: value)], []);
        expectRejected([
          expense(split: {'b': value}),
        ], []);
        expectRejected([], [payment(value)]);
        expectRejected([], [payment(value, from: 'a', to: 'a')]);
      }
      expectRejected([expense(split: {})], []);
      expectRejected([
        expense(split: {'b': 9.99}),
      ], []);
      expectRejected([expense(payer: ' ')], []);
      expectRejected([
        expense(split: {'': 10}),
      ], []);
      expectRejected([], [payment(1, from: '')]);
      expectRejected([], [payment(1, to: ' ')]);
    });

    test('blank users and duplicate/blank members are rejected', () {
      expect(
        () => BalanceCalculator.totalBalance(
          currentUserId: ' ',
          expenses: [],
          settlements: [],
        ),
        throwsArgumentError,
      );
      for (final members in [
        ['a', 'a'],
        [''],
      ]) {
        expect(
          () => BalanceCalculator.simplifyDebts(
            expenses: [],
            settlements: [],
            memberIds: members,
          ),
          throwsArgumentError,
        );
      }
    });
  });

  test('empty inputs remain valid and return zero/no debts', () {
    expect(
      BalanceCalculator.calculateNetBalances(
        currentUserId: 'a',
        expenses: [],
        settlements: [],
      ),
      isEmpty,
    );
    expect(
      BalanceCalculator.totalBalance(
        currentUserId: 'a',
        expenses: [],
        settlements: [],
      ),
      0,
    );
    expect(
      BalanceCalculator.simplifyDebts(
        memberIds: [],
        expenses: [],
        settlements: [],
      ),
      isEmpty,
    );
    const balance = UserBalance(userId: 'a', amount: 1.0);
    const debt = SimplifiedDebt(from: 'b', to: 'a', amount: 1.0);
    expect(balance.amount, debt.amount);
  });
}
