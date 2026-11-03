import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_it/core/utils/money.dart';
import 'package:split_it/features/auth/providers/auth_provider.dart';
import 'package:split_it/features/expenses/data/expenses_repository.dart';
import 'package:split_it/features/expenses/presentation/screens/add_expense_screen.dart';
import 'package:split_it/features/expenses/providers/expenses_provider.dart';
import 'package:split_it/features/groups/providers/groups_provider.dart';
import 'package:split_it/features/settle/data/settlements_repository.dart';
import 'package:split_it/features/settle/presentation/screens/settle_up_screen.dart';
import 'package:split_it/features/settle/providers/settlements_provider.dart';
import 'package:split_it/shared/models/app_user.dart';
import 'package:split_it/shared/models/expense.dart';
import 'package:split_it/shared/models/group.dart';
import 'package:split_it/shared/models/settlement.dart';

class _UnusedExpensesRepository implements ExpensesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedSettlementsRepository implements SettlementsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Expenses extends ExpensesNotifier {
  _Expenses() : super(_UnusedExpensesRepository());
  final saved = <Expense>[];
  final committed = <String, Expense>{};
  bool loseResponseOnce = false;
  Completer<void>? pending;
  bool fail = false;

  @override
  Future<void> saveExpense(Expense expense) async {
    saved.add(expense);
    if (fail) throw StateError('Offline');
    await pending?.future;
    committed[expense.id] = expense;
    if (loseResponseOnce) {
      loseResponseOnce = false;
      throw StateError('Committed, but response lost');
    }
  }
}

class _Settlements extends SettlementsNotifier {
  _Settlements() : super(_UnusedSettlementsRepository());
  final saved = <Settlement>[];
  final committed = <String, Settlement>{};
  bool loseResponseOnce = false;
  Completer<void>? pending;
  bool fail = false;

  @override
  Future<void> saveSettlement(Settlement settlement) async {
    saved.add(settlement);
    if (fail) throw StateError('Offline');
    await pending?.future;
    committed[settlement.id] = settlement;
    if (loseResponseOnce) {
      loseResponseOnce = false;
      throw StateError('Committed, but response lost');
    }
  }
}

final _group = Group(
  id: 'group',
  name: 'Trip',
  createdBy: 'a',
  createdAt: DateTime(2026),
  memberIds: const ['a', 'b', 'c'],
  currency: 'EUR',
);
final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

Future<void> _mount(
  WidgetTester tester, {
  bool settle = false,
  _Expenses? expenses,
  _Settlements? settlements,
  AppUser? user = const AppUser(uid: 'a'),
  Future<Group?> Function()? loadGroup,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(user),
      groupProvider('group').overrideWith(
          (ref) async => loadGroup == null ? _group : await loadGroup()),
      if (expenses != null)
        expensesNotifierProvider.overrideWith((ref) => expenses),
      if (settlements != null)
        settlementsNotifierProvider.overrideWith((ref) => settlements),
    ],
    child: MaterialApp(
        home: settle
            ? const SettleUpScreen(groupId: 'group')
            : const AddExpenseScreen(groupId: 'group')),
  ));
  await tester.pump();
}

final _sessionUserProvider =
    StateProvider<AppUser?>((ref) => const AppUser(uid: 'a'));
final _formGroupProvider = StateProvider<String>((ref) => 'group');

Future<ProviderContainer> _mountMutable(
  WidgetTester tester, {
  required bool settle,
  required _Expenses expenses,
  required _Settlements settlements,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserProvider
          .overrideWith((ref) => ref.watch(_sessionUserProvider)),
      groupProvider.overrideWith((ref, id) async => Group(
            id: id,
            name: 'Trip',
            createdBy: 'a',
            createdAt: DateTime(2026),
            memberIds: const ['a', 'b', 'c'],
            currency: 'EUR',
          )),
      expensesNotifierProvider.overrideWith((ref) => expenses),
      settlementsNotifierProvider.overrideWith((ref) => settlements),
    ],
    child: Consumer(builder: (context, ref, _) {
      final groupId = ref.watch(_formGroupProvider);
      return MaterialApp(
          home: settle
              ? SettleUpScreen(groupId: groupId)
              : AddExpenseScreen(groupId: groupId));
    }),
  ));
  await tester.pump();
  final screen = find.byType(settle ? SettleUpScreen : AddExpenseScreen);
  return ProviderScope.containerOf(tester.element(screen));
}

Future<void> _fillSettlement(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('b').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField), '12.34');
}

Future<void> fillExpense(WidgetTester tester, String amount) async {
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'), ' Dinner ');
  await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), amount);
  await tester.pump();
}

Future<void> submit(WidgetTester tester, String label) async {
  final button = find.widgetWithText(ElevatedButton, label);
  FocusManager.instance.primaryFocus?.unfocus();
  if (find.byType(SnackBar).evaluate().isNotEmpty) {
    ScaffoldMessenger.of(tester.element(button)).removeCurrentSnackBar();
  }
  await tester.pumpAndSettle();
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pump();
}

void main() {
  for (final settle in [false, true]) {
    final kind = settle ? 'settlement' : 'expense';
    final label = settle ? 'Record Settlement' : 'Add Expense';
    testWidgets(
        '$kind retries a lost committed response with the same draft UUID',
        (tester) async {
      final expenses = _Expenses()..loseResponseOnce = true;
      final settlements = _Settlements()..loseResponseOnce = true;
      await _mount(tester,
          settle: settle, expenses: expenses, settlements: settlements);
      if (settle) {
        await _fillSettlement(tester);
      } else {
        await fillExpense(tester, '10.00');
      }
      await submit(tester, label);
      expect(
          find.textContaining('Committed, but response lost'), findsOneWidget);
      final firstId =
          settle ? settlements.saved.single.id : expenses.saved.single.id;
      expect(firstId, matches(_uuid));
      await submit(tester, label);
      final ids = settle
          ? settlements.saved.map((record) => record.id).toList()
          : expenses.saved.map((record) => record.id).toList();
      expect(ids, [firstId, firstId]);
      expect(
          settle ? settlements.committed.length : expenses.committed.length, 1);
      await tester.pumpAndSettle();
    });

    for (final changeAccount in [true, false]) {
      testWidgets(
          '$kind rejects stale ${changeAccount ? 'account' : 'group'} even after switching back and completing old save',
          (tester) async {
        final pending = Completer<void>();
        final expenses = _Expenses()..pending = pending;
        final settlements = _Settlements()..pending = pending;
        final container = await _mountMutable(tester,
            settle: settle, expenses: expenses, settlements: settlements);
        if (settle) {
          await _fillSettlement(tester);
        } else {
          await fillExpense(tester, '10.00');
        }
        final oldSubmit = tester
            .widget<ElevatedButton>(find.byType(ElevatedButton))
            .onPressed!;
        await submit(tester, label);
        if (changeAccount) {
          container.read(_sessionUserProvider.notifier).state =
              const AppUser(uid: 'b');
        } else {
          container.read(_formGroupProvider.notifier).state = 'other-group';
        }
        await tester.pump();
        expect(find.textContaining('Reopen this form'), findsOneWidget);
        oldSubmit();
        if (changeAccount) {
          container.read(_sessionUserProvider.notifier).state =
              const AppUser(uid: 'a');
        } else {
          container.read(_formGroupProvider.notifier).state = 'group';
        }
        await tester.pump();
        expect(find.textContaining('Reopen this form'), findsOneWidget);
        if (changeAccount) {
          pending.complete();
        } else {
          pending.completeError(StateError('Old request failed'));
        }
        await tester.pumpAndSettle();
        oldSubmit();
        await tester.pump();
        expect(settle ? settlements.saved.length : expenses.saved.length, 1);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byType(Form), findsNothing);
      });
    }
  }
  testWidgets('equal split saves exact cents, UUID and prevents double submit',
      (tester) async {
    final notifier = _Expenses()..pending = Completer<void>();
    await _mount(tester, expenses: notifier);
    await fillExpense(tester, '10.00');
    expect(find.text('3.34 EUR'), findsOneWidget);
    expect(find.text('3.33 EUR'), findsNWidgets(2));
    await submit(tester, 'Add Expense');
    expect(notifier.saved, hasLength(1));
    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    await tester.pump();
    expect(notifier.saved, hasLength(1));
    final expense = notifier.saved.single;
    expect(expense.id, matches(_uuid));
    expect(expense.description, 'Dinner');
    expect(expense.createdBy, 'a');
    expect(expense.paidBy, 'a');
    expect(expense.split, {'a': 3.34, 'b': 3.33, 'c': 3.33});
    expect(
        expense.split.values.map(Money.toMinor).reduce((a, b) => a + b), 1000);
    notifier.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Expense added successfully'), findsOneWidget);
  });

  testWidgets(
      'custom split rejects mismatch then saves exact shares including zero',
      (tester) async {
    final notifier = _Expenses();
    await _mount(tester, expenses: notifier);
    await fillExpense(tester, '10.00');
    await tester.tap(find.text('Split Equally'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom Amounts').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('share-a')), '0');
    await tester.enterText(find.byKey(const ValueKey('share-b')), '6.66');
    await tester.enterText(find.byKey(const ValueKey('share-c')), '3.33');
    await submit(tester, 'Add Expense');
    expect(notifier.saved, isEmpty);
    expect(find.textContaining('Custom shares must add up exactly'),
        findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('share-c')), '3.34');
    await submit(tester, 'Add Expense');
    expect(notifier.saved.single.split, {'a': 0, 'b': 6.66, 'c': 3.34});
    await tester.pumpAndSettle();
  });

  testWidgets('invalid expense input never submits and errors permit retry',
      (tester) async {
    final notifier = _Expenses()..fail = true;
    await _mount(tester, expenses: notifier);
    for (final input in [
      'NaN',
      'Infinity',
      '1e2',
      '1.001',
      '0',
      '-1',
      '10000000000'
    ]) {
      await fillExpense(tester, input);
      await submit(tester, 'Add Expense');
      expect(notifier.saved, isEmpty, reason: input);
    }
    await fillExpense(tester, '1.00');
    await submit(tester, 'Add Expense');
    expect(find.textContaining('Offline'), findsOneWidget);
    notifier.fail = false;
    await submit(tester, 'Add Expense');
    expect(notifier.saved, hasLength(2));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'settlement records own payment in group currency, not a transfer',
      (tester) async {
    final notifier = _Settlements()..pending = Completer<void>();
    await _mount(tester, settle: true, settlements: notifier);
    expect(find.textContaining('This does not transfer money'), findsOneWidget);
    expect(find.text('EUR'), findsOneWidget);
    await submit(tester, 'Record Settlement');
    expect(notifier.saved, isEmpty);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('a'), findsNothing);
    await tester.tap(find.text('b').last);
    await tester.pumpAndSettle();
    for (final input in ['NaN', '1.001', '0', '-1']) {
      await tester.enterText(find.byType(TextFormField), input);
      await submit(tester, 'Record Settlement');
      expect(notifier.saved, isEmpty);
    }
    await tester.enterText(find.byType(TextFormField), '12.34');
    await submit(tester, 'Record Settlement');
    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    await tester.pump();
    expect(notifier.saved, hasLength(1));
    expect(notifier.saved.single.id, matches(_uuid));
    expect(notifier.saved.single.paidBy, 'a');
    expect(notifier.saved.single.paidTo, 'b');
    expect(notifier.saved.single.amount, 12.34);
    notifier.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('12.34 EUR recorded. No money was transferred.'),
        findsOneWidget);
  });

  testWidgets('group errors retry and signed out/nonmember users cannot submit',
      (tester) async {
    var attempts = 0;
    await _mount(tester, loadGroup: () async {
      if (attempts++ == 0) throw StateError('Unavailable');
      return _group;
    });
    expect(find.textContaining('Unable to load group'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(Form), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await _mount(tester, user: null);
    expect(find.text('Sign in to add an expense'), findsOneWidget);
    expect(find.byType(Form), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await _mount(tester, settle: true, user: const AppUser(uid: 'outsider'));
    expect(find.text('A valid group membership is required'), findsOneWidget);
    expect(find.byType(Form), findsNothing);
  });
}
