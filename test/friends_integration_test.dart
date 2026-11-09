import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:split_it/features/auth/providers/auth_provider.dart';
import 'package:split_it/features/expenses/providers/expenses_provider.dart';
import 'package:split_it/features/friends/data/friends_repository.dart';
import 'package:split_it/features/friends/presentation/screens/add_friend_screen.dart';
import 'package:split_it/features/friends/presentation/screens/friend_detail_screen.dart';
import 'package:split_it/features/friends/presentation/screens/friends_screen.dart';
import 'package:split_it/features/friends/providers/friends_provider.dart';
import 'package:split_it/features/groups/data/groups_repository.dart';
import 'package:split_it/features/groups/providers/groups_provider.dart';
import 'package:split_it/features/settle/providers/settlements_provider.dart';
import 'package:split_it/shared/models/app_user.dart';
import 'package:split_it/shared/models/expense.dart';
import 'package:split_it/shared/models/friend.dart';
import 'package:split_it/shared/models/group.dart';
import 'package:split_it/shared/models/settlement.dart';

const _friend = Friend(id: 'b', userId1: 'a', userId2: 'b', friendName: 'Bea');
final _session = StateProvider<AppUser?>((ref) => const AppUser(uid: 'a'));

class _Repository implements FriendsRepository {
  final friends = <Friend>[];
  final requests = <FriendRequest>[];
  final responses = <(String, bool)>[];
  final removed = <String>[];
  Friend? sent;
  bool fail = false;
  int reads = 0;
  Completer<void>? pending;

  @override
  Future<List<Friend>> getFriends(String userId) async {
    reads++;
    if (fail) throw StateError('Offline');
    return List.of(friends);
  }

  @override
  Future<List<FriendRequest>> getFriendRequests() async {
    if (fail) throw StateError('Offline');
    return List.of(requests);
  }

  @override
  Future<void> addFriend(Friend friend) async {
    sent = friend;
    await pending?.future;
    if (fail) throw StateError('Offline');
  }

  @override
  Future<void> respondToFriendRequest(String requesterId,
      {required bool accept}) async {
    await pending?.future;
    if (fail) throw StateError('Offline');
    responses.add((requesterId, accept));
    requests.removeWhere((request) => request.requesterId == requesterId);
    if (accept) friends.add(_friend);
  }

  @override
  Future<void> removeFriend(String friendId) async {
    removed.add(friendId);
    friends.removeWhere((friend) => friend.id == friendId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Group _group(String id, String currency) => Group(
      id: id,
      name: id,
      currency: currency,
      createdBy: 'a',
      createdAt: DateTime(2026),
      memberIds: const ['a', 'b', 'c'],
    );

Expense _expense(
        String id, String group, String payer, Map<String, double> split) =>
    Expense(
      id: id,
      groupId: group,
      description: id,
      amount: split.values.fold(0.0, (a, b) => a + b),
      paidBy: payer,
      date: DateTime(2026),
      split: split,
      createdBy: 'a',
    );

FriendRequest _request(String id) => FriendRequest(
      requesterId: id,
      addresseeId: 'a',
      displayName: 'Bea',
      createdAt: DateTime(2026),
    );

List<Override> _overrides(_Repository repository) => [
      currentUserProvider.overrideWith((ref) => ref.watch(_session)),
      friendsRepositoryProvider.overrideWithValue(repository),
      groupsProvider.overrideWith(
          (ref) async => GroupPage(groups: [_group('eur', 'EUR'), _group('usd', 'USD')], hasNext: false)),
      expensesProvider.overrideWith((ref, groupId) async => groupId == 'eur'
          ? [
              _expense('Dinner', groupId, 'a', {'a': 10, 'b': 20}),
              _expense('Not shared', groupId, 'c', {'b': 99})
            ]
          : [
              _expense('Lunch', groupId, 'b', {'a': 20, 'b': 10})
            ]),
      settlementsProvider.overrideWith((ref, groupId) async => groupId == 'eur'
          ? [
              Settlement(
                  id: 's',
                  groupId: groupId,
                  paidBy: 'b',
                  paidTo: 'a',
                  amount: 5,
                  date: DateTime(2026))
            ]
          : []),
    ];

void main() {
  test('balances include settlements without offsetting different currencies',
      () async {
    final container = ProviderContainer(overrides: _overrides(_Repository()));
    addTearDown(container.dispose);
    final data = await container.read(friendFinancialsProvider('b').future);
    expect(data.balances, {'EUR': 15, 'USD': -20});
    expect(data.expenses.map((e) => e.expense.id),
        containsAll(['Dinner', 'Lunch']));
    expect(
        data.expenses.map((e) => e.expense.id), isNot(contains('Not shared')));
    expect(data.expenses.map((e) => e.currency).toSet(), {'EUR', 'USD'});
  });

  test('accept, decline and removal invalidate lists and single friend',
      () async {
    final repository = _Repository()..requests.add(_request('b'));
    final container = ProviderContainer(overrides: _overrides(repository));
    addTearDown(container.dispose);
    expect(await container.read(singleFriendProvider('b').future), isNull);
    expect(await container.read(friendRequestsProvider.future), hasLength(1));
    await container
        .read(friendsNotifierProvider.notifier)
        .respondToFriendRequest('b', accept: true);
    expect(await container.read(singleFriendProvider('b').future), _friend);
    expect(await container.read(friendRequestsProvider.future), isEmpty);
    repository.requests.add(_request('c'));
    await container
        .read(friendsNotifierProvider.notifier)
        .respondToFriendRequest('c', accept: false);
    expect(repository.responses, [('b', true), ('c', false)]);
    await container.read(friendsNotifierProvider.notifier).removeFriend('b');
    expect(await container.read(singleFriendProvider('b').future), isNull);
    expect(repository.removed, ['b']);
  });

  test('signed out friend providers are empty and mutations are rejected',
      () async {
    final repository = _Repository()..friends.add(_friend);
    final container = ProviderContainer(overrides: _overrides(repository));
    addTearDown(container.dispose);
    await container.read(singleFriendProvider('b').future);
    await container.read(friendFinancialsProvider('b').future);
    container.read(_session.notifier).state = null;
    expect(await container.read(friendsProvider.future), isEmpty);
    expect(await container.read(friendRequestsProvider.future), isEmpty);
    expect(await container.read(singleFriendProvider('b').future), isNull);
    expect(
        (await container.read(friendFinancialsProvider('b').future)).balances,
        isEmpty);
    await expectLater(
        container.read(friendsNotifierProvider.notifier).removeFriend('b'),
        throwsStateError);
    expect(repository.removed, isEmpty);
  });

  test('account switch recomputes balances with auth-scoped ledger caches',
      () async {
    var expenseReads = 0;
    var settlementReads = 0;
    final container = ProviderContainer(overrides: [
      ..._overrides(_Repository()),
      expensesProvider.overrideWith((ref, id) async {
        ref.watch(currentUserProvider);
        expenseReads++;
        return [
          _expense('Dinner', id, 'b', {'a': 5, 'c': 12})
        ];
      }),
      settlementsProvider.overrideWith((ref, id) async {
        ref.watch(currentUserProvider);
        settlementReads++;
        return [];
      }),
    ]);
    addTearDown(container.dispose);
    expect(
        (await container.read(friendFinancialsProvider('b').future)).balances,
        {'EUR': -5, 'USD': -5});
    container.read(_session.notifier).state = const AppUser(uid: 'c');
    expect(
        (await container.read(friendFinancialsProvider('b').future)).balances,
        {'EUR': -12, 'USD': -12});
    expect(expenseReads, 4);
    expect(settlementReads, 4);
  });

  test('in-flight mutation cannot publish after an account switch', () async {
    final repository = _Repository()..pending = Completer<void>();
    final container = ProviderContainer(overrides: _overrides(repository));
    addTearDown(container.dispose);
    final old = container.read(friendsNotifierProvider.notifier);
    final mutation = old.addFriend(_friend);
    container.read(_session.notifier).state = const AppUser(uid: 'c');
    final next = container.read(friendsNotifierProvider.notifier);
    expect(next, isNot(same(old)));
    repository.pending!.complete();
    await mutation;
    expect(container.read(friendsNotifierProvider).isLoading, isFalse);
  });

  testWidgets('incoming request accepts and refreshes accepted friends',
      (tester) async {
    final repository = _Repository()..requests.add(_request('b'));
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(repository),
      child: const MaterialApp(home: FriendsScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(repository.responses, [('b', true)]);
    expect(find.text('Accept'), findsNothing);
    expect(find.text('View shared expenses'), findsOneWidget);
  });

  testWidgets('failed incoming response stays retryable', (tester) async {
    final repository = _Repository()..requests.add(_request('b'));
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(repository),
      child: const MaterialApp(home: FriendsScreen()),
    ));
    await tester.pumpAndSettle();
    repository.fail = true;
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not respond'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    expect(repository.responses, [('b', false)]);
  });

  testWidgets('request submission is privacy safe and never says added',
      (tester) async {
    final repository = _Repository();
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
                  body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => context.push('/add'),
                    child: const Text('Open')),
              ))),
      GoRoute(path: '/add', builder: (_, __) => const AddFriendScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(repository),
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Friend Name'), 'Bea');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'nobody@example.com');
    await tester.ensureVisible(find.text('Send Request'));
    await tester.tap(find.text('Send Request'));
    await tester.pumpAndSettle();
    expect(repository.sent?.friendEmail, 'nobody@example.com');
    expect(find.textContaining('Friend request sent.'), findsOneWidget);
    expect(find.textContaining('Friend added'), findsNothing);
    expect(repository.friends, isEmpty);
  });

  testWidgets('detail shows currency balances and shared expenses navigate',
      (tester) async {
    final repository = _Repository()..friends.add(_friend);
    final router = GoRouter(initialLocation: '/friend', routes: [
      GoRoute(
          path: '/friend',
          builder: (_, __) => const FriendDetailScreen(friendId: 'b')),
      GoRoute(
          path: '/expense/:id',
          builder: (_, state) => Scaffold(
                body: Text('Expense ${state.pathParameters['id']}'),
              )),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(repository),
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Bea owes you EUR 15.00'), findsOneWidget);
    expect(find.text('You owe Bea USD 20.00'), findsOneWidget);
    expect(find.text('All settled up'), findsNothing);
    await tester.ensureVisible(find.text('Dinner'));
    await tester.tap(find.text('Dinner'));
    await tester.pumpAndSettle();
    expect(find.text('Expense Dinner'), findsOneWidget);
  });

  testWidgets('financial load failures show retry instead of settled balance',
      (tester) async {
    var fail = true;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ..._overrides(_Repository()..friends.add(_friend)),
        settlementsProvider.overrideWith((ref, id) async {
          if (fail) throw StateError('Offline');
          return [];
        }),
      ],
      child: const MaterialApp(home: FriendDetailScreen(friendId: 'b')),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load balances'), findsOneWidget);
    expect(find.text('All settled up'), findsNothing);
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Bea owes you EUR 20.00'), findsOneWidget);
  });
}
