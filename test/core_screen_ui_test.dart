import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:split_it/features/activity/presentation/screens/activity_screen.dart';
import 'package:split_it/features/activity/providers/activity_provider.dart';
import 'package:split_it/features/auth/providers/auth_provider.dart';
import 'package:split_it/features/expenses/data/expenses_repository.dart';
import 'package:split_it/features/expenses/presentation/screens/expense_detail_screen.dart';
import 'package:split_it/features/expenses/providers/expenses_provider.dart';
import 'package:split_it/features/friends/providers/friends_provider.dart';
import 'package:split_it/features/groups/data/groups_repository.dart';
import 'package:split_it/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:split_it/features/groups/providers/groups_provider.dart';
import 'package:split_it/features/settle/providers/settlements_provider.dart';
import 'package:split_it/shared/models/app_user.dart';
import 'package:split_it/shared/models/expense.dart';
import 'package:split_it/shared/models/friend.dart';
import 'package:split_it/shared/models/group.dart';
import 'package:split_it/shared/models/settlement.dart';

class _UnusedExpensesRepository implements ExpensesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedGroupsRepository implements GroupsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Deletes extends ExpensesNotifier {
  _Deletes() : super(_UnusedExpensesRepository());
  final deleted = <Expense>[];
  Completer<void>? pending;
  bool fail = false;

  @override
  Future<void> deleteExpense(Expense expense) async {
    deleted.add(expense);
    await pending?.future;
    if (fail) throw StateError('Delete offline');
  }
}

class _Members extends GroupsNotifier {
  _Members() : super(_UnusedGroupsRepository());
  final added = <String>[];
  Completer<void>? pending;
  bool fail = false;

  @override
  Future<void> addMember(String groupId, String memberId) async {
    added.add(memberId);
    await pending?.future;
    if (fail) throw StateError('Member offline');
  }
}

final _group = Group(
  id: 'g',
  name: 'Trip',
  createdBy: 'owner',
  createdAt: DateTime(2026),
  memberIds: const ['owner', 'me'],
  currency: 'EUR',
);
final _expense = Expense(
  id: 'e',
  groupId: 'g',
  description: 'Dinner',
  amount: 24,
  paidBy: 'owner',
  date: DateTime(2026, 4, 2),
  split: const {'owner': 12, 'me': 12},
  createdBy: 'owner',
);
final _settlement = Settlement(
  id: 's',
  groupId: 'g',
  paidBy: 'me',
  paidTo: 'owner',
  amount: 5,
  date: DateTime(2026, 4, 3),
  note: 'Cash payment',
);
const _friend = Friend(
    id: 'friend', userId1: 'owner', userId2: 'friend', friendName: 'Alice');
const _existing = Friend(
    id: 'me', userId1: 'owner', userId2: 'me', friendName: 'Already in group');

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  String screen = 'group',
  String userId = 'me',
  _Deletes? deletes,
  _Members? members,
  Future<Group?> Function()? loadGroup,
  Future<List<Friend>> Function()? loadFriends,
  Future<List<Expense>> Function()? loadExpenses,
  Future<List<Settlement>> Function()? loadSettlements,
  Future<List<Expense>> Function()? loadActivity,
  Future<List<Group>> Function()? loadGroups,
  Map<String, int>? reads,
}) async {
  final router = GoRouter(
    initialLocation: '/$screen',
    routes: [
      GoRoute(
          path: '/group',
          builder: (context, state) => const GroupDetailScreen(groupId: 'g')),
      GoRoute(
          path: '/expense',
          builder: (context, state) =>
              const ExpenseDetailScreen(expenseId: 'e')),
      GoRoute(
          path: '/activity',
          builder: (context, state) => const ActivityScreen()),
      GoRoute(
          path: '/expense/:id',
          builder: (context, state) =>
              Scaffold(body: Text('Opened ${state.pathParameters['id']}'))),
      GoRoute(
          path: '/groups/:groupId/settle',
          name: 'group-settle',
          builder: (context, state) =>
              const Scaffold(body: Text('Settle route'))),
      GoRoute(
          path: '/groups/:groupId',
          builder: (context, state) =>
              const Scaffold(body: Text('Returned to group'))),
    ],
  );
  addTearDown(router.dispose);
  void count(String key) {
    if (reads != null) reads[key] = (reads[key] ?? 0) + 1;
  }

  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(AppUser(uid: userId)),
      groupProvider('g').overrideWith((ref) async {
        count('group');
        return loadGroup == null ? _group : await loadGroup();
      }),
      groupsProvider.overrideWith((ref) async {
        count('groups');
        final list = loadGroups == null ? [_group] : await loadGroups();
        return GroupPage(groups: list, hasNext: false);
      }),
      singleExpenseProvider('e').overrideWith((ref) async {
        count('single');
        return _expense;
      }),
      expensesProvider('g').overrideWith((ref) async {
        count('expenses');
        return loadExpenses == null ? [_expense] : await loadExpenses();
      }),
      settlementsProvider('g').overrideWith((ref) async =>
          loadSettlements == null ? [_settlement] : await loadSettlements()),
      friendsProvider.overrideWith((ref) async =>
          loadFriends == null ? [_friend, _existing] : await loadFriends()),
      allUserExpensesProvider.overrideWith((ref) async {
        count('allUser');
        return [_expense];
      }),
      allExpensesProvider.overrideWith((ref) async {
        count('activity');
        return loadActivity == null ? [_expense] : await loadActivity();
      }),
      friendFinancialsProvider('friend').overrideWith((ref) async {
        count('financials');
        return const FriendFinancials(balances: {}, expenses: []);
      }),
      expensesNotifierProvider.overrideWith((ref) => deletes ?? _Deletes()),
      groupsNotifierProvider.overrideWith((ref) => members ?? _Members()),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
}

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pump();
}

Future<void> _delete(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Delete expense'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete'));
  await tester.pump();
}

void main() {
  final chainGroup = _group.copyWith(memberIds: ['a', 'b', 'c']);
  final chainExpenses = [
    Expense(
      id: 'ab',
      groupId: 'g',
      description: 'B paid for A',
      amount: 10,
      paidBy: 'b',
      date: DateTime(2026),
      split: const {'a': 10},
      createdBy: 'b',
    ),
    Expense(
      id: 'bc',
      groupId: 'g',
      description: 'C paid for B',
      amount: 10,
      paidBy: 'c',
      date: DateTime(2026),
      split: const {'b': 10},
      createdBy: 'c',
    ),
  ];
  Settlement payment(String from, String to) => Settlement(
        id: '$from-$to',
        groupId: 'g',
        paidBy: from,
        paidTo: to,
        amount: 10,
        date: DateTime(2026, 2),
      );

  testWidgets('group shows actual chain obligations without redirecting debts',
      (tester) async {
    await _mount(
      tester,
      loadGroup: () async => chainGroup,
      loadExpenses: () async => chainExpenses,
      loadSettlements: () async => [],
    );
    await tester.pumpAndSettle();
    expect(find.text('a owes b'), findsOneWidget);
    expect(find.text('b owes c'), findsOneWidget);
    expect(find.text('a owes c'), findsNothing);
    expect(find.text('All settled up!'), findsNothing);
    expect(find.textContaining('Debts are not reassigned'), findsOneWidget);
  });

  testWidgets('paying each original creditor settles the chain pairwise',
      (tester) async {
    final payments = <Settlement>[];
    final container = await _mount(
      tester,
      loadGroup: () async => chainGroup,
      loadExpenses: () async => chainExpenses,
      loadSettlements: () async => [...payments],
    );
    await tester.pumpAndSettle();
    payments.add(payment('a', 'b'));
    container.invalidate(settlementsProvider('g'));
    await tester.pumpAndSettle();
    expect(find.text('a owes b'), findsNothing);
    expect(find.text('b owes c'), findsOneWidget);
    expect(find.text('All settled up!'), findsNothing);

    payments.add(payment('b', 'c'));
    container.invalidate(settlementsProvider('g'));
    await tester.pumpAndSettle();
    expect(find.text('b owes c'), findsNothing);
    expect(find.text('All settled up!'), findsOneWidget);
  });

  testWidgets('redirected payment does not falsely settle pairwise obligations',
      (tester) async {
    await _mount(
      tester,
      loadGroup: () async => chainGroup,
      loadExpenses: () async => chainExpenses,
      loadSettlements: () async => [payment('a', 'c')],
    );
    await tester.pumpAndSettle();
    // Overall net positions are zero, but all three pairwise debts remain.
    expect(find.text('a owes b'), findsOneWidget);
    expect(find.text('b owes c'), findsOneWidget);
    expect(find.text('c owes a'), findsOneWidget);
    expect(find.text('All settled up!'), findsNothing);
  });

  testWidgets(
      'pairwise balances include historical expense and payment participants',
      (tester) async {
    await _mount(
      tester,
      loadGroup: () async => chainGroup.copyWith(memberIds: ['b']),
      loadExpenses: () async => chainExpenses,
      loadSettlements: () async => [payment('d', 'e')],
    );
    await tester.pumpAndSettle();
    expect(find.text('a owes b'), findsOneWidget);
    expect(find.text('b owes c'), findsOneWidget);
    expect(find.text('e owes d'), findsOneWidget);
    expect(find.text('All settled up!'), findsNothing);
  });

  testWidgets('group labels creator relative to viewer and uses group currency',
      (tester) async {
    await _mount(tester);
    await tester.pumpAndSettle();
    expect(find.text('Creator'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('You (Creator)'), findsNothing);
    expect(find.text('Add Member'), findsNothing);
    expect(find.text('7.00 EUR'), findsOneWidget);
    expect(find.text('24.00 EUR'), findsOneWidget);
    expect(find.text('5.00 EUR'), findsOneWidget);
    expect(find.text('You → owner'), findsOneWidget);
    expect(find.textContaining('Cash payment'), findsOneWidget);
    await _tap(tester, 'Settle Up');
    await tester.pumpAndSettle();
    expect(find.text('Settle route'), findsOneWidget);
  });

  testWidgets(
      'owner selects only eligible accepted friends, with guarded submit',
      (tester) async {
    final members = _Members()..pending = Completer<void>();
    await _mount(tester, userId: 'owner', members: members);
    await tester.pumpAndSettle();
    expect(find.text('You (Creator)'), findsOneWidget);
    await _tap(tester, 'Add Member');
    await tester.pumpAndSettle();
    expect(find.text('Member User ID'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Already in group'), findsNothing);
    await tester.tap(find.text('Alice').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    expect(members.added, ['friend']);
    expect(find.text('Adding…'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Adding…'))
            .onPressed,
        isNull);
    members.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('friend load failure is visible and retry recovers',
      (tester) async {
    var attempts = 0;
    await _mount(tester, userId: 'owner', loadFriends: () async {
      if (attempts++ == 0) throw StateError('Friends offline');
      return [];
    });
    await tester.pumpAndSettle();
    await _tap(tester, 'Add Member');
    await tester.pumpAndSettle();
    expect(find.textContaining('Friends offline'), findsOneWidget);
    await _tap(tester, 'Retry');
    await tester.pumpAndSettle();
    expect(find.textContaining('No friends available'), findsOneWidget);
  });

  testWidgets('add-member failure remains visible and can be retried',
      (tester) async {
    final members = _Members()..fail = true;
    await _mount(tester, userId: 'owner', members: members);
    await tester.pumpAndSettle();
    await _tap(tester, 'Add Member');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice').last);
    await tester.pumpAndSettle();
    await _tap(tester, 'Add');
    await tester.pumpAndSettle();
    expect(find.textContaining('Member offline'), findsOneWidget);
    members.fail = false;
    await _tap(tester, 'Add');
    await tester.pumpAndSettle();
    expect(members.added, ['friend', 'friend']);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('settlement failures are not hidden and support retry',
      (tester) async {
    var attempts = 0;
    await _mount(tester, loadSettlements: () async {
      if (attempts++ == 0) throw StateError('Settlement offline');
      return [_settlement];
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load balances'), findsOneWidget);
    expect(find.textContaining('Could not load settlements'), findsOneWidget);
    await _tap(tester, 'Retry');
    await tester.pumpAndSettle();
    expect(find.text('5.00 EUR'), findsOneWidget);
    expect(find.text('7.00 EUR'), findsOneWidget);
  });

  testWidgets('expense header, shares and total use the group currency',
      (tester) async {
    await _mount(tester, screen: 'expense');
    await tester.pumpAndSettle();
    expect(find.text('24.00 EUR'), findsNWidgets(2));
    expect(find.text('12.00 EUR'), findsNWidgets(2));
    expect(find.textContaining('\$'), findsNothing);
  });

  testWidgets('expense waits for currency and exposes currency-load retry',
      (tester) async {
    final pending = Completer<Group?>();
    var attempts = 0;
    await _mount(tester, screen: 'expense', loadGroup: () {
      if (attempts++ == 0) return pending.future;
      return Future.value(_group);
    });
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('24.00'), findsNothing);
    pending.completeError(StateError('Currency offline'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Currency offline'), findsOneWidget);
    await _tap(tester, 'Retry');
    await tester.pumpAndSettle();
    expect(find.text('24.00 EUR'), findsNWidgets(2));
  });

  testWidgets('deletion can be cancelled and a failed delete is actionable',
      (tester) async {
    final deletes = _Deletes()..fail = true;
    await _mount(tester, screen: 'expense', deletes: deletes);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete expense'));
    await tester.pumpAndSettle();
    await _tap(tester, 'Cancel');
    await tester.pumpAndSettle();
    expect(deletes.deleted, isEmpty);
    await _delete(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Failed to delete:'), findsOneWidget);
    expect(find.text('Expense Detail'), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) =>
                widget is IconButton && widget.tooltip == 'Delete expense'))
            .onPressed,
        isNotNull);
  });

  testWidgets('deletion blocks duplicates and refreshes all dependent views',
      (tester) async {
    final deletes = _Deletes()..pending = Completer<void>();
    final reads = <String, int>{};
    final container =
        await _mount(tester, screen: 'expense', deletes: deletes, reads: reads);
    final subscriptions = [
      container.listen(expensesProvider('g'), (previous, next) {}),
      container.listen(groupsProvider, (previous, next) {}),
      container.listen(allUserExpensesProvider, (previous, next) {}),
      container.listen(allExpensesProvider, (previous, next) {}),
      container.listen(friendFinancialsProvider('friend'), (previous, next) {}),
      container.listen(groupProvider('g'), (previous, next) {}),
      container.listen(singleExpenseProvider('e'), (previous, next) {}),
    ];
    addTearDown(() {
      for (final subscription in subscriptions) {
        subscription.close();
      }
    });
    await tester.pumpAndSettle();
    final before = Map<String, int>.from(reads);
    await _delete(tester);
    expect(deletes.deleted, [_expense]);
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) =>
                widget is IconButton && widget.tooltip == 'Delete expense'))
            .onPressed,
        isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    deletes.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Returned to group'), findsOneWidget);
    for (final key in [
      'group',
      'groups',
      'single',
      'expenses',
      'allUser',
      'activity',
      'financials'
    ]) {
      expect(reads[key], greaterThan(before[key]!),
          reason: '$key was not refreshed');
    }
  });

  testWidgets(
      'activity is a refreshable expense history with group currencies and navigation',
      (tester) async {
    final otherGroup = Group(
        id: 'other',
        name: 'Holiday',
        createdBy: 'me',
        createdAt: DateTime(2026),
        memberIds: const ['me'],
        currency: 'GBP');
    final otherExpense = Expense(
        id: 'newer',
        groupId: 'other',
        description: 'Taxi',
        amount: 9,
        paidBy: 'me',
        date: DateTime(2026, 5),
        split: const {'me': 9},
        createdBy: 'me');
    await _mount(tester,
        screen: 'activity',
        loadActivity: () async => [_expense, otherExpense],
        loadGroups: () async => [_group, otherGroup]);
    await tester.pumpAndSettle();
    expect(find.textContaining('Not a live feed'), findsOneWidget);
    expect(find.text('24.00 EUR'), findsOneWidget);
    expect(find.text('9.00 GBP'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Taxi')).dy,
        lessThan(tester.getTopLeft(find.text('Dinner')).dy));
    await _tap(tester, 'Taxi');
    await tester.pumpAndSettle();
    expect(find.text('Opened newer'), findsOneWidget);
  });

  testWidgets('activity loading, errors, retry and empty refresh are supported',
      (tester) async {
    final pending = Completer<List<Expense>>();
    var attempts = 0;
    await _mount(tester, screen: 'activity', loadActivity: () {
      if (attempts++ == 0) return pending.future;
      return Future.value([]);
    });
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(StateError('Activity offline'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Activity offline'), findsOneWidget);
    await _tap(tester, 'Retry');
    await tester.pumpAndSettle();
    expect(find.text('No activity yet'), findsOneWidget);
    await tester.tap(find.byTooltip('Refresh activity'));
    await tester.pumpAndSettle();
    expect(attempts, 3);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('activity does not invent USD for a missing group',
      (tester) async {
    await _mount(tester, screen: 'activity', loadGroups: () async => []);
    await tester.pumpAndSettle();
    expect(find.text('Currency\nunavailable'), findsOneWidget);
    expect(find.textContaining('USD'), findsNothing);
    expect(find.textContaining('24.00'), findsNothing);
  });
}
