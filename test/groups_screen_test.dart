import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:split_it/features/auth/providers/auth_provider.dart';
import 'package:split_it/features/expenses/data/expenses_repository.dart';
import 'package:split_it/features/expenses/providers/expenses_provider.dart';
import 'package:split_it/features/groups/data/groups_repository.dart';
import 'package:split_it/features/groups/presentation/screens/create_group_screen.dart';
import 'package:split_it/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:split_it/features/groups/presentation/screens/groups_screen.dart';
import 'package:split_it/features/groups/providers/groups_provider.dart';
import 'package:split_it/features/settle/data/settlements_repository.dart';
import 'package:split_it/features/settle/providers/settlements_provider.dart';
import 'package:split_it/shared/models/app_user.dart';
import 'package:split_it/shared/models/group.dart';

Group _group() => Group(
      id: 'group',
      name: 'Trip',
      createdBy: 'owner',
      createdAt: DateTime(2026),
      memberIds: const ['owner', 'member'],
      members: const [
        GroupMember(userId: 'owner', displayName: 'Owner', role: 'owner'),
        GroupMember(userId: 'member', displayName: 'Friend', role: 'member'),
      ],
    );

final _financialOverrides = [
  expensePageProvider.overrideWith(
      (ref, id) async => const ExpensePage(expenses: [], hasNext: false)),
  settlementPageProvider.overrideWith(
      (ref, id) async => const SettlementPage(settlements: [], hasNext: false)),
  groupBalancesProvider
      .overrideWith((ref, id) async => {'owner': 0, 'member': 0}),
];

void main() {
  testWidgets('only actual current member is labelled You', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(const AppUser(uid: 'member')),
        groupProvider('group').overrideWith((ref) async => _group()),
        ..._financialOverrides,
      ],
      child: const MaterialApp(home: GroupDetailScreen(groupId: 'group')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Your net balance'), findsOneWidget);
    expect(find.text('All settled up!'), findsNothing);
    await tester.scrollUntilVisible(find.text('Friend (You)'), 200);
    expect(find.text('Friend (You)'), findsOneWidget);
    expect(find.text('Owner (You)'), findsNothing);
    expect(find.text('Invite by email'), findsNothing);
  });

  testWidgets('owner sees email invitation with validation', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(const AppUser(uid: 'owner')),
        groupProvider('group').overrideWith((ref) async => _group()),
        ..._financialOverrides,
      ],
      child: const MaterialApp(home: GroupDetailScreen(groupId: 'group')),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Owner (You)'), 200);
    expect(find.text('Owner (You)'), findsOneWidget);
    await tester.ensureVisible(find.text('Invite by email'));
    await tester.tap(find.text('Invite by email'));
    await tester.pumpAndSettle();
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Member User ID'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Invite to group'), findsNothing);
  });

  testWidgets('group list uses member count and next/back paging',
      (tester) async {
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWithValue(const AppUser(uid: 'owner')),
      groupsProvider.overrideWith((ref) async {
        final page = ref.watch(groupsPageProvider);
        return GroupPage(groups: [_group()], hasNext: page == 0);
      }),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: GroupsScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('2 members · USD'), findsOneWidget);
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('Page 2'), findsOneWidget);
    expect(container.read(groupsPageProvider), 1);
    await tester.tap(find.byTooltip('Previous page'));
    await tester.pumpAndSettle();
    expect(find.text('Page 1'), findsOneWidget);
  });

  testWidgets('invitation inbox explains no email is sent', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(const AppUser(uid: 'member')),
        groupsProvider.overrideWith(
            (ref) async => const GroupPage(groups: [], hasNext: false)),
        groupInvitesProvider.overrideWith((ref) async => []),
      ],
      child: const MaterialApp(home: GroupsScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Group invitations'));
    await tester.pumpAndSettle();
    expect(find.text('Invites appear here, not in a separate email.'),
        findsOneWidget);
    expect(find.text('No pending invitations.'), findsOneWidget);
  });

  testWidgets('create form requires a name and offers PKR currency',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: CreateGroupScreen()),
    ));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Group'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a group name'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('PKR'), findsOneWidget);
  });

  testWidgets(
      'create waits for persistence, prevents double submit, then opens detail',
      (tester) async {
    final repository = _FakeRepository([]);
    repository.pendingCreate = Completer<void>();
    final router = GoRouter(initialLocation: '/create', routes: [
      GoRoute(path: '/create', builder: (_, __) => const CreateGroupScreen()),
      GoRoute(
        path: '/groups/:groupId',
        builder: (_, state) =>
            GroupDetailScreen(groupId: state.pathParameters['groupId']!),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(const AppUser(uid: 'owner')),
        groupsRepositoryProvider.overrideWithValue(repository),
        ..._financialOverrides,
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.enterText(find.byType(TextFormField).first, 'Trip');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Group'));
    await tester.pump();
    expect(repository.created, hasLength(1));
    expect(find.byType(GroupDetailScreen), findsNothing);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    repository.pendingCreate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(GroupDetailScreen), findsOneWidget);
    expect(repository.created.single.createdBy, 'owner');
  });

  test('group detail cache reloads on account switch and clears on logout',
      () async {
    final testUser =
        StateProvider<AppUser?>((ref) => const AppUser(uid: 'first'));
    final calls = <String>[];
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) => ref.watch(testUser)),
      groupsRepositoryProvider.overrideWith((ref) => _FakeRepository(calls)),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(groupProvider('group'), (_, __) {});
    addTearDown(sub.close);

    expect((await container.read(groupProvider('group').future))?.name, 'Trip');
    container.read(testUser.notifier).state = const AppUser(uid: 'second');
    expect((await container.read(groupProvider('group').future))?.name, 'Trip');
    expect(calls, hasLength(2));
    container.read(testUser.notifier).state = null;
    expect(await container.read(groupProvider('group').future), isNull);
    expect(calls, hasLength(2));
  });

  test('list and invitation pages reset when the signed-in account changes',
      () {
    final testUser =
        StateProvider<AppUser?>((ref) => const AppUser(uid: 'first'));
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) => ref.watch(testUser)),
    ]);
    addTearDown(container.dispose);
    final groups = container.listen(groupsPageProvider, (_, __) {});
    final invites = container.listen(invitesPageProvider, (_, __) {});
    addTearDown(groups.close);
    addTearDown(invites.close);
    container.read(groupsPageProvider.notifier).state = 2;
    container.read(invitesPageProvider.notifier).state = 3;
    container.read(testUser.notifier).state = const AppUser(uid: 'second');
    expect(container.read(groupsPageProvider), 0);
    expect(container.read(invitesPageProvider), 0);
  });
}

// No SDK client is needed because all repository methods used here are replaced.
class _FakeRepository implements GroupsRepository {
  final List<String> calls;
  final List<Group> created = [];
  Completer<void>? pendingCreate;
  _FakeRepository(this.calls);

  @override
  Future<void> createGroup(Group group) async {
    created.add(group);
    await pendingCreate?.future;
  }

  @override
  Future<Group?> getGroup(String id) async {
    calls.add(id);
    return _group();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
