import 'package:flutter_test/flutter_test.dart';
import 'package:split_it/core/utils/money.dart';
import 'package:split_it/shared/models/expense.dart';

void main() {
  group('two-decimal money boundary', () {
    test(
      'rounds decimal halves up without binary multiplication artifacts',
      () {
        expect(Money.toMinorUnits(1.005), 101);
        expect(Money.toMinorUnits(2.675), 268);
        expect(Money.toMinorUnits(0.0049), 0);
        expect(Money.toMinorUnits(0.005), 1);
        expect(Money.toMinorUnits(0.1 + 0.2), 30);
        expect(Money.toMinorUnits(1e-7), 0);
        expect(Money.toMinorUnits(-0.0), 0);
        expect(Money.fromMinorUnits(-1), -0.01);
      },
    );

    test('rejects negative, nonfinite and excessive amounts', () {
      for (final value in [
        -0.001,
        double.nan,
        double.infinity,
        double.negativeInfinity,
        1e100,
      ]) {
        expect(() => Money.toMinorUnits(value), throwsArgumentError);
      }
      expect(() => Money.add(Money.maxMinorUnits, 1), throwsArgumentError);
      expect(
        () => Money.fromMinorUnits(-Money.maxMinorUnits - 1),
        throwsArgumentError,
      );
      for (final units in [
        0,
        1,
        -1,
        101,
        Money.maxMinorUnits,
        Money.maxMinorUnits - 1,
      ]) {
        expect(
          Money.toMinorUnits(Money.fromMinorUnits(units).abs()),
          units.abs(),
        );
      }
    });
  });

  group('Expense equal split', () {
    test('assigns awkward remainders by ID, not member input order', () {
      expect(Expense.splitEqually(amount: 10, memberIds: ['c', 'a', 'b']), {
        'a': 3.34,
        'b': 3.33,
        'c': 3.33,
      });
      expect(Expense.splitEqually(amount: 0.02, memberIds: ['c', 'b', 'a']), {
        'a': 0.01,
        'b': 0.01,
        'c': 0.0,
      });
      expect(Expense.splitEqually(amount: 0, memberIds: ['a']), {'a': 0.0});
    });

    test('conserves cents across many totals and group sizes', () {
      for (var count = 1; count <= 17; count++) {
        final ids = List.generate(count, (i) => 'user-$i');
        for (var cents = 0; cents <= 201; cents++) {
          final split = Expense.splitEqually(
            amount: cents / 100,
            memberIds: ids.reversed.toList(),
          );
          final units = split.values.map(Money.toMinorUnits).toList();
          expect(units.fold<int>(0, (a, b) => a + b), cents);
          expect(
            units.reduce((a, b) => a > b ? a : b) -
                units.reduce((a, b) => a < b ? a : b),
            lessThanOrEqualTo(1),
          );
        }
      }
    });

    test(
      'rejects missing, duplicate and blank members and invalid amounts',
      () {
        for (final members in [
          <String>[],
          ['a', 'a'],
          ['a', ''],
          ['a', '  '],
        ]) {
          expect(
            () => Expense.splitEqually(amount: 1, memberIds: members),
            throwsArgumentError,
          );
        }
        expect(
          () => Expense.splitEqually(amount: -1, memberIds: ['a']),
          throwsArgumentError,
        );
      },
    );
  });

  group('legacy share normalization', () {
    test('conserves thirds and prioritizes largest fractional remainders', () {
      expect(
        Money.allocateShares(10, {'c': 10 / 3, 'b': 10 / 3, 'a': 10 / 3}),
        {'a': 334, 'b': 333, 'c': 333},
      );
      expect(Money.allocateShares(1, {'a': 0.331, 'b': 0.339, 'c': 0.330}), {
        'a': 33,
        'b': 34,
        'c': 33,
      });
      expect(Money.allocateShares(0.01, {'b': 0.005, 'a': 0.005}), {
        'a': 1,
        'b': 0,
      });
      expect(Money.allocateShares(0.3, {'a': 0.1, 'b': 0.2}), {
        'a': 10,
        'b': 20,
      });
    });

    test('rejects malformed shares rather than silently inventing money', () {
      for (final shares in [
        <String, double>{},
        {'a': 0.99},
        {'a': 1.01},
        {'': 1.0},
        {'a': -1.0, 'b': 2.0},
        {'a': double.nan},
        {'a': double.infinity},
      ]) {
        expect(() => Money.allocateShares(1, shares), throwsArgumentError);
      }
    });
  });

  test('Expense serialization and double constructor remain compatible', () {
    final expense = Expense(
      id: 'e',
      groupId: 'g',
      description: 'Thirds',
      amount: 1,
      paidBy: 'a',
      date: DateTime(2025),
      split: const {'c': 1 / 3, 'a': 1 / 3, 'b': 1 / 3},
      createdBy: 'a',
    );
    final original = Map<String, double>.from(expense.split);
    expect(expense.splitInMinorUnits, {'a': 34, 'b': 33, 'c': 33});
    expect(expense.split, original);
    final map = expense.toMap();
    expect(map['amount'], isA<double>());
    expect(map['split'], isA<String>());
    expect(Expense.fromMap(map), expense);
    expect(Expense.fromMap({...map, 'split': original}), expense);
    expect(Expense.fromMap(map).splitInMinorUnits, expense.splitInMinorUnits);
  });
}
