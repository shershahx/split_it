import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_it/features/activity/providers/activity_provider.dart';
import 'package:split_it/features/auth/providers/auth_provider.dart';
import 'package:split_it/features/expenses/data/expenses_repository.dart';
import 'package:split_it/features/expenses/providers/expenses_provider.dart';
import 'package:split_it/features/friends/providers/friends_provider.dart';
import 'package:split_it/features/groups/data/groups_repository.dart';
import 'package:split_it/features/groups/providers/groups_provider.dart';
import 'package:split_it/features/settle/data/settlements_repository.dart';
import 'package:split_it/features/settle/providers/settlements_provider.dart';
import 'package:split_it/shared/models/app_user.dart';
import 'package:split_it/shared/models/expense.dart';
import 'package:split_it/shared/models/group.dart';
import 'package:split_it/shared/models/settlement.dart';

final _session = StateProvider<AppUser?>((ref) => const AppUser(uid: 'a'));

Expense _expense(String uid, double share) => Expense(
      id: 'expense',
      groupId: 'group',
      description: '$uid expense',
      amount: share,
      paidBy: uid,
      date: DateTime(2026),
      split: {'friend': share},
      createdBy: uid,
    );

Settlement _settlement(String uid, double amount) => Settlement(
      id: 'settlement',
      groupId: 'group',
      paidBy: 'friend',
      paidTo: uid,
      amount: amount,
      date: DateTime(2026),
    );

class _Account {
  _Account(String uid, double share, double payment)
      : group = Group(
          id: 'group',
          name: '$uid group',
          createdBy: uid,
          createdAt: DateTime(2026),
          memberIds: [uid, 'friend'],
          currency: 'EUR',
        ),
        expenses = [_expense(uid, share)],
        settlements = [_settlement(uid, payment)];

  final Group group;
  final List<Expense> expenses;
  final List<Settlement> settlements;
}

class _Backend {
  String? uid = 'a';
  final accounts = {'a': _Account('a', 20, 5), 'b': _Account('b', 70, 10)};
  final reads = <String, int>{};
  final gates = <String, Completer<void>>{};
  bool failMutation = false;

  _Account get current => accounts[uid]!;

  // Capture each response at invocation, before a later account switch or write.
  Future<T> read<T>(String method, T snapshot) async {
    final account = uid!;
    final key = '$account/$method';
    reads[key] = (reads[key] ?? 0) + 1;
    await gates[account]?.future;
    return snapshot;
  }

  void checkMutation() {
    if (failMutation) throw StateError('Offline');
  }
}

class _GroupsRepository implements GroupsRepository {
  _GroupsRepository(this.backend);
  final _Backend backend;

  @override
  Future<GroupPage> getGroups({int page = 0}) async {
    final list = await backend.read('groups', [backend.current.group]);
    return GroupPage(groups: list, hasNext: false);
  }

  @override
  Future<Group?> getGroup(String groupId) =>
      backend.read('group', backend.current.group);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ExpensesRepository implements ExpensesRepository {
  _ExpensesRepository(this.backend);
  final _Backend backend;

  @override
  Future<ExpensePage> getExpenses(String groupId, {int page = 0}) async {
    final list = await backend.read('expenses', List.of(backend.current.expenses));
    return ExpensePage(expenses: list, hasNext: false);
  }

  @override
  Future<Expense?> getExpenseById(String expenseId) => backend.read(
      'expense',
      backend.current.expenses.isEmpty
          ? null
          : backend.current.expenses.single);

  @override
  Future<void> saveExpense(Expense expense) async {
    backend.checkMutation();
    backend.current.expenses
      ..removeWhere((item) => item.id == expense.id)
      ..add(expense);
  }

  @override
  Future<void> deleteExpense(Expense expense) async {
    backend.checkMutation();
    backend.current.expenses.removeWhere((item) => item.id == expense.id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SettlementsRepository implements SettlementsRepository {
  _SettlementsRepository(this.backend);
  final _Backend backend;

  @override
  Future<List<Settlement>> getSettlements(String groupId) =>
      backend.read('settlements', List.of(backend.current.settlements));

  @override
  Future<void> saveSettlement(Settlement settlement) async {
    backend.checkMutation();
    backend.current.settlements
      ..removeWhere((item) => item.id == settlement.id)
      ..add(settlement);
  }

  @override
  Future<void> deleteSettlement(Settlement settlement) async {
    backend.checkMutation();
    backend.current.settlements.removeWhere((item) => item.id == settlement.id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness {
  _Harness() {
    // Override only the session and repositories, never the providers under test.
    container = ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) => ref.watch(_session)),
      groupsRepositoryProvider.overrideWithValue(_GroupsRepository(backend)),
      expensesRepositoryProvider
          .overrideWithValue(_ExpensesRepository(backend)),
      settlementsRepositoryProvider
          .overrideWithValue(_SettlementsRepository(backend)),
    ]);
    addTearDown(container.dispose);
  }

  final backend = _Backend();
  late final ProviderContainer container;

  void switchAccount(String? uid) {
    backend.uid = uid;
    container.read(_session.notifier).state =
        uid == null ? null : AppUser(uid: uid);
  }

  Future<void> expectAccount(String uid, double balance) async {
    expect((await container.read(groupsProvider.future)).single.name,
        '$uid group');
    expect((await container.read(groupProvider('group').future))?.name,
        '$uid group');
    expect(
        (await container.read(expensesProvider('group').future))
            .single
            .description,
        '$uid expense');
    expect(
        (await container.read(singleExpenseProvider('expense').future))
            ?.description,
        '$uid expense');
    expect(
        (await container.read(settlementsProvider('group').future))
            .single
            .paidTo,
        uid);
    expect(
        (await container.read(allUserExpensesProvider.future))
            .single
            .description,
        '$uid expense');
    expect(
        (await container.read(allExpensesProvider.future)).single.description,
        '$uid expense');
    final financials =
        await container.read(friendFinancialsProvider('friend').future);
    expect(financials.balances, {'EUR': balance});
    expect(financials.expenses.single.expense.description, '$uid expense');
  }
}

void main() {
  test('real core providers refetch identical IDs after account switches',
      () async {
    final harness = _Harness();
    await harness.expectAccount('a', 15);
    harness.switchAccount('b');
    await harness.expectAccount('b', 60);
    harness.switchAccount('a');
    await harness.expectAccount('a', 15);
    for (final method in [
      'groups',
      'group',
      'expenses',
      'expense',
      'settlements'
    ]) {
      expect(harness.backend.reads['a/$method'], 2,
          reason: '$method must refetch on return to a');
      expect(harness.backend.reads['b/$method'], 1,
          reason: '$method must fetch b rather than reuse a');
    }
  });

  test('sign-out clears core and derived data without repository reads',
      () async {
    final harness = _Harness();
    final container = harness.container;
    await harness.expectAccount('a', 15);
    final reads = Map.of(harness.backend.reads);
    harness.switchAccount(null);
    expect(await container.read(groupsProvider.future), isEmpty);
    expect(await container.read(groupProvider('group').future), isNull);
    expect(await container.read(expensesProvider('group').future), isEmpty);
    expect(
        await container.read(singleExpenseProvider('expense').future), isNull);
    expect(await container.read(settlementsProvider('group').future), isEmpty);
    expect(await container.read(allUserExpensesProvider.future), isEmpty);
    expect(await container.read(allExpensesProvider.future), isEmpty);
    final financials =
        await container.read(friendFinancialsProvider('friend').future);
    expect(financials.balances, isEmpty);
    expect(financials.expenses, isEmpty);
    expect(harness.backend.reads, reads);
    harness.switchAccount('b');
    await harness.expectAccount('b', 60);
  });

  test('same-UID profile updates do not refetch core financial caches',
      () async {
    final harness = _Harness();
    await harness.expectAccount('a', 15);
    final reads = Map.of(harness.backend.reads);
    harness.container.read(_session.notifier).state =
        const AppUser(uid: 'a', displayName: 'Updated profile');
    await harness.expectAccount('a', 15);
    expect(harness.backend.reads, reads);
  });

  test('late responses from an old account cannot replace new account caches',
      () async {
    final harness = _Harness();
    final container = harness.container;
    final gate = Completer<void>();
    harness.backend.gates['a'] = gate;
    final obsolete = <Future<Object?>>[
      container.read(groupsProvider.future),
      container.read(groupProvider('group').future),
      container.read(expensesProvider('group').future),
      container.read(singleExpenseProvider('expense').future),
      container.read(settlementsProvider('group').future),
      container.read(allExpensesProvider.future),
      container.read(friendFinancialsProvider('friend').future),
    ];
    harness.switchAccount('b');
    await harness.expectAccount('b', 60);
    final reads = Map.of(harness.backend.reads);
    gate.complete();
    await Future.wait(obsolete);
    await container.pump();
    await harness.expectAccount('b', 60);
    expect(harness.backend.reads, reads);
  });

  test('expense save and delete centrally refresh activity and friends',
      () async {
    final harness = _Harness();
    final container = harness.container;
    // Keep the real consumers subscribed, as they would be on mounted screens.
    container.listen(allExpensesProvider, (_, __) {});
    container.listen(friendFinancialsProvider('friend'), (_, __) {});
    await harness.expectAccount('a', 15);
    final updated = _expense('a', 40);
    await container
        .read(expensesNotifierProvider.notifier)
        .saveExpense(updated);
    expect(await container.read(allExpensesProvider.future), [updated]);
    expect(await container.read(allUserExpensesProvider.future), [updated]);
    expect(await container.read(expensesProvider('group').future), [updated]);
    expect(
        await container.read(singleExpenseProvider('expense').future), updated);
    expect(
        (await container.read(friendFinancialsProvider('friend').future))
            .balances,
        {'EUR': 35});
    expect(
        (await container.read(friendFinancialsProvider('friend').future))
            .expenses
            .single
            .expense,
        updated);

    await container
        .read(expensesNotifierProvider.notifier)
        .deleteExpense(updated);
    expect(await container.read(allExpensesProvider.future), isEmpty);
    expect(await container.read(allUserExpensesProvider.future), isEmpty);
    expect(await container.read(expensesProvider('group').future), isEmpty);
    expect(
        await container.read(singleExpenseProvider('expense').future), isNull);
    final financials =
        await container.read(friendFinancialsProvider('friend').future);
    expect(financials.expenses, isEmpty);
    // The prior payment remains a credit after its expense is removed.
    expect(financials.balances, {'EUR': -5});
  });

  test(
      'settlement save and delete refresh friends without altering expense activity',
      () async {
    final harness = _Harness();
    final container = harness.container;
    container.listen(allExpensesProvider, (_, __) {});
    container.listen(friendFinancialsProvider('friend'), (_, __) {});
    await harness.expectAccount('a', 15);
    final activity = await container.read(allExpensesProvider.future);
    final updated = _settlement('a', 12);
    await container
        .read(settlementsNotifierProvider.notifier)
        .saveSettlement(updated);
    expect(
        await container.read(settlementsProvider('group').future), [updated]);
    expect(
        (await container.read(friendFinancialsProvider('friend').future))
            .balances,
        {'EUR': 8});
    expect(await container.read(allExpensesProvider.future), activity);

    await container
        .read(settlementsNotifierProvider.notifier)
        .deleteSettlement(updated);
    expect(await container.read(settlementsProvider('group').future), isEmpty);
    expect(
        (await container.read(friendFinancialsProvider('friend').future))
            .balances,
        {'EUR': 20});
    // Activity currently contains expenses only, not settlement events.
    expect(await container.read(allExpensesProvider.future), activity);
  });

  test('failed mutations preserve cached activity and friend financials',
      () async {
    final harness = _Harness();
    final container = harness.container;
    await harness.expectAccount('a', 15);
    final reads = Map.of(harness.backend.reads);
    harness.backend.failMutation = true;
    await expectLater(
        container
            .read(expensesNotifierProvider.notifier)
            .saveExpense(_expense('a', 99)),
        throwsStateError);
    await expectLater(
        container
            .read(settlementsNotifierProvider.notifier)
            .saveSettlement(_settlement('a', 99)),
        throwsStateError);
    await harness.expectAccount('a', 15);
    expect(harness.backend.reads, reads);
    expect(container.read(expensesNotifierProvider).hasError, isTrue);
    expect(container.read(settlementsNotifierProvider).hasError, isTrue);
  });
}
