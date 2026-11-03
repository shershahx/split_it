import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:split_it/features/auth/providers/auth_provider.dart';
import 'package:split_it/features/expenses/data/expenses_repository.dart';
import 'package:split_it/features/expenses/presentation/screens/add_expense_screen.dart';
import 'package:split_it/features/groups/providers/groups_provider.dart';
import 'package:split_it/shared/models/app_user.dart';
import 'package:split_it/shared/models/expense.dart';
import 'package:split_it/shared/models/group.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _member = '33333333-3333-4333-8333-333333333333';
const _groupId = '22222222-2222-4222-8222-222222222222';

class _Repository implements ExpensesRepository {
  final saved = <Expense>[];
  Completer<void>? pending;
  bool fail = false;

  @override
  Future<void> saveExpense(Expense expense) async {
    saved.add(expense);
    await pending?.future;
    if (fail) throw StateError('private transport detail');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _open(WidgetTester tester, _Repository repository,
    {void Function(bool?)? onResult}) async {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => Scaffold(
        body: TextButton(
          child: const Text('Open'),
          onPressed: () async {
            final result = await context.push<bool>('/expense');
            onResult?.call(result);
          },
        ),
      ),
    ),
    GoRoute(
      path: '/expense',
      builder: (_, __) => const AddExpenseScreen(groupId: _groupId),
    ),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(const AppUser(uid: _owner)),
      expensesRepositoryProvider.overrideWithValue(repository),
      groupProvider(_groupId).overrideWith((ref) async => Group(
            id: _groupId,
            name: 'Trip',
            createdBy: _owner,
            createdAt: DateTime(2026),
            currency: 'PKR',
            memberIds: const [_owner, _member],
            members: const [
              GroupMember(
                  userId: _owner, displayName: 'Sher', role: 'owner'),
              GroupMember(
                  userId: _member, displayName: 'Ayesha', role: 'member'),
            ],
          )),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, {String amount = '10.01'}) async {
  await tester.enterText(find.byType(TextFormField).first, 'Dinner');
  await tester.enterText(find.byType(TextFormField).last, amount);
}

Future<void> _submit(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byType(FilledButton),
    150,
    scrollable: find
        .descendant(
            of: find.byType(ListView), matching: find.byType(Scrollable))
        .first,
  );
  await tester.tap(find.byType(FilledButton));
  await tester.pump();
}

void main() {
  testWidgets('exact equal split saves once and returns true after persistence',
      (tester) async {
    final repository = _Repository()..pending = Completer<void>();
    bool? result;
    await _open(tester, repository, onResult: (value) => result = value);
    expect(find.text('Amount (PKR)'), findsOneWidget);
    await _fill(tester);
    await _submit(tester);
    await _submit(tester);
    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.splitInMinorUnits,
        {_owner: 501, _member: 500});
    expect(repository.saved.single.currency, 'PKR');
    expect(repository.saved.single.paidBy, _owner);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AddExpenseScreen), findsOneWidget);
    repository.pending!.complete();
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.byType(AddExpenseScreen), findsNothing);
  });

  testWidgets('unchanged retry keeps ID and timestamp; edited input gets new ID',
      (tester) async {
    final repository = _Repository()..fail = true;
    await _open(tester, repository);
    await _fill(tester);
    await _submit(tester);
    await _submit(tester);
    expect(repository.saved, hasLength(2));
    expect(repository.saved[1].id, repository.saved[0].id);
    expect(repository.saved[1].date, repository.saved[0].date);
    expect(find.textContaining('private transport detail'), findsNothing);
    await tester.enterText(find.byType(TextFormField).last, '10.02');
    await _submit(tester);
    expect(repository.saved[2].id, isNot(repository.saved[0].id));
    expect(repository.saved[2].splitInMinorUnits,
        {_owner: 501, _member: 501});
  });

  testWidgets('invalid amounts never reach persistence', (tester) async {
    final repository = _Repository();
    await _open(tester, repository);
    for (final invalid in ['0', '-1', 'NaN', 'Infinity', '1e2', '1.234']) {
      await _fill(tester, amount: invalid);
      await _submit(tester);
      expect(repository.saved, isEmpty, reason: invalid);
    }
  });
}
