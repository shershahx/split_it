import 'package:flutter_test/flutter_test.dart';
import 'package:split_it/core/utils/money.dart';
<<<<<<< HEAD

void main() {
  test('aggregate conversion has a separate documented exact-cent limit', () {
    expect(Money.maxMinorUnits, 999999999999);
    expect(Money.maxAggregateMinorUnits, 35184372088831);
    for (final cents in [
      0,
      1,
      -1,
      Money.maxMinorUnits + 1,
      -Money.maxMinorUnits - 1,
      Money.maxAggregateMinorUnits,
      -Money.maxAggregateMinorUnits,
    ]) {
      final major = Money.toMajorAggregate(cents);
      expect(major.toStringAsFixed(2), Money.formatMinor(cents));
      expect((major * 100).round(), cents);
    }
    expect(() => Money.toMajor(Money.maxMinorUnits + 1), throwsFormatException);
    expect(() => Money.toMinor(Money.toMajorAggregate(Money.maxMinorUnits + 1)),
        throwsFormatException);
    for (final cents in [
      Money.maxAggregateMinorUnits + 1,
      -Money.maxAggregateMinorUnits - 1
    ]) {
      expect(
          () => Money.toMajorAggregate(cents),
          throwsA(isA<StateError>()
              .having((error) => error.message, 'message',
                  contains('Filter to fewer records'))
              .having((error) => error.message, 'message',
                  contains('integer-cent reporting'))));
    }
  });
  test('parses cents exactly and formats signed amounts', () {
    expect(Money.parseMinor(' 10.01 '), 1001);
    expect(Money.parseMinor('0.1'), 10);
    expect(Money.parseMinor('-0.01'), -1);
    expect(Money.parseMinor('+12'), 1200);
    expect(Money.formatMinor(-101), '-1.01');
    expect(Money.formatMinor(0), '0.00');
    expect(Money.parseMinor('9999999999.99'), Money.maxMinorUnits);
  });

  test('rejects invalid, fractional-cent, nonfinite and oversized input', () {
    for (final value in [
      '',
      '.',
      '1.',
      '.5',
      '1.001',
      '1e2',
      'NaN',
      'Infinity',
      '1,000',
      '10000000000',
      '--1'
    ]) {
      expect(() => Money.parseMinor(value), throwsFormatException,
          reason: value);
      expect(Money.tryParseMinor(value), isNull, reason: value);
    }
    for (final value in [double.nan, double.infinity, -double.infinity, 1e20]) {
      expect(() => Money.toMinor(value), throwsFormatException);
    }
    expect(() => Money.toMajor(Money.maxMinorUnits + 1), throwsFormatException);
  });

  test('quantizes historical doubles half away from zero', () {
    expect(Money.toMinor(1.005), 101);
    expect(Money.toMinor(-1.005), -101);
    expect(Money.toMinor(0.1 + 0.2), 30);
    expect(Money.toMinor(1e-7), 0);
    for (final cents in [
      0,
      1,
      -1,
      29,
      1001,
      Money.maxMinorUnits,
      -Money.maxMinorUnits
    ]) {
      expect(Money.toMinor(Money.toMajor(cents)), cents);
    }
  });

  test('equal splits distribute all remainder cents in member order', () {
    expect(Money.equalSplitMinor(1000, ['a', 'b', 'c']),
        {'a': 334, 'b': 333, 'c': 333});
    expect(Money.equalSplitMinor(1, ['c', 'a', 'b']), {'c': 1, 'a': 0, 'b': 0});
    for (var amount = 0; amount < 200; amount++) {
      final split = Money.equalSplitMinor(amount, ['a', 'b', 'c']);
      expect(split.values.reduce((a, b) => a + b), amount);
      Money.validateSplitMinor(
          total: amount, split: split, memberIds: ['a', 'b', 'c']);
    }
  });

  test('rejects malformed membership and custom splits', () {
    for (final members in <List<String>>[
      [],
      ['a', 'a'],
      ['a', ' ']
    ]) {
      expect(() => Money.equalSplitMinor(100, members), throwsArgumentError);
    }
    expect(() => Money.equalSplitMinor(-1, ['a']), throwsArgumentError);
    for (final split in <Map<String, int>>[
      {'a': 100},
      {'a': 50, 'x': 50},
      {'a': -1, 'b': 101},
      {'a': 50, 'b': 49},
      {'a': 50, 'b': 51},
    ]) {
      expect(
          () => Money.validateSplitMinor(
              total: 100, split: split, memberIds: ['a', 'b']),
          throwsArgumentError);
    }
    Money.validateSplitMinor(
        total: 100, split: {'a': 0, 'b': 100}, memberIds: ['a', 'b']);
  });

  test('payments must be your own positive payment to another member', () {
    void validate(
        {String current = 'a',
        String payer = 'a',
        String recipient = 'b',
        int amount = 100}) {
      Money.validateSettlementMinor(
          currentUserId: current,
          paidBy: payer,
          paidTo: recipient,
          amount: amount,
          memberIds: ['a', 'b']);
    }

    validate(amount: Money.maxMinorUnits); // Overpayments create credit.
    expect(() => validate(payer: 'b', recipient: 'a'), throwsArgumentError);
    expect(() => validate(recipient: 'a'), throwsArgumentError);
    expect(() => validate(recipient: 'outsider'), throwsArgumentError);
    expect(() => validate(current: ''), throwsArgumentError);
    expect(() => validate(amount: 0), throwsArgumentError);
    expect(() => validate(amount: -1), throwsArgumentError);
    expect(
        () => validate(amount: Money.maxMinorUnits + 1), throwsArgumentError);
=======
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
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
  });
}
