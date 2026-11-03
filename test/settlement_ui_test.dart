import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_it/features/auth/providers/auth_provider.dart';
import 'package:split_it/features/groups/providers/groups_provider.dart';
import 'package:split_it/features/settle/data/settlements_repository.dart';
import 'package:split_it/features/settle/presentation/screens/settle_up_screen.dart';
import 'package:split_it/shared/models/app_user.dart';
import 'package:split_it/shared/models/group.dart';
import 'package:split_it/shared/models/settlement.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _payer = '11111111-1111-4111-8111-111111111111';
const _recipient = '33333333-3333-4333-8333-333333333333';
const _groupId = '22222222-2222-4222-8222-222222222222';

Group _group({String currency = 'PKR'}) => Group(
      id: _groupId,
      name: 'Trip',
      createdBy: _payer,
      createdAt: DateTime(2026),
      currency: currency,
      memberIds: const [_payer, _recipient],
      members: const [
        GroupMember(userId: _payer, displayName: 'My name', role: 'owner'),
        GroupMember(userId: _recipient, displayName: 'Ayesha', role: 'member'),
      ],
    );

class _Repository implements SettlementsRepository {
  final saved = <Settlement>[];
  Completer<void>? pending;
  Object? failure;

  @override
  Future<void> saveSettlement(Settlement settlement) async {
    saved.add(settlement);
    await pending?.future;
    if (failure != null) throw failure!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _open(WidgetTester tester, _Repository repository,
    {AppUser? user = const AppUser(uid: _payer),
    String currency = 'PKR',
    void Function(bool?)? onResult}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(user),
      groupProvider(_groupId)
          .overrideWith((ref) async => _group(currency: currency)),
      settlementsRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      home: Builder(builder: (context) {
        return Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                    builder: (_) => const SettleUpScreen(groupId: _groupId)),
              );
              onResult?.call(result);
            },
            child: const Text('Open'),
          ),
        );
      }),
    ),
  ));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, {String amount = '12.34'}) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ayesha').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, amount);
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.tap(find.byType(FilledButton));
  await tester.pump();
}

void main() {
  testWidgets('named members, group currency and explicit no-transfer notice',
      (tester) async {
    await _open(tester, _Repository());
    expect(find.text('Amount (PKR)'), findsOneWidget);
    expect(find.textContaining('does not transfer money'), findsOneWidget);
    expect(find.textContaining(_recipient), findsNothing);
    expect(find.textContaining(r'$'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Ayesha'), findsOneWidget);
    expect(find.text('My name'), findsNothing);
  });

  testWidgets('requires recipient, positive exact amount and bounded note',
      (tester) async {
    final repository = _Repository();
    await _open(tester, repository);
    await _submit(tester);
    expect(find.text('Select another group member.'), findsOneWidget);
    await _fill(tester);
    for (final invalid in ['0', '-1', 'NaN', 'Infinity', '1.234', '1e2']) {
      await tester.enterText(find.byType(TextFormField).first, invalid);
      await _submit(tester);
      expect(repository.saved, isEmpty, reason: invalid);
    }
    await tester.enterText(find.byType(TextFormField).first, '1.00');
    await tester.enterText(find.byType(TextFormField).last, 'x' * 301);
    await _submit(tester);
    expect(
        find.text('Keep the note to 300 characters or fewer.'), findsOneWidget);
    expect(repository.saved, isEmpty);
  });

  testWidgets('busy blocks double tap and back, success pops with true',
      (tester) async {
    final repository = _Repository()..pending = Completer<void>();
    bool? result;
    await _open(tester, repository, onResult: (value) => result = value);
    await _fill(tester);
    await _submit(tester);
    await _submit(tester);
    expect(repository.saved, hasLength(1));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(
        tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
        isFalse);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(SettleUpScreen), findsOneWidget);
    repository.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(SettleUpScreen), findsNothing);
    expect(result, isTrue);
    expect(repository.saved.single.amount, 12.34);
    expect(repository.saved.single.id, matches(RegExp(r'^[a-f0-9-]{36}$')));
  });

  testWidgets('unchanged uncertain retry reuses whole request; edits change ID',
      (tester) async {
    final repository = _Repository()
      ..failure = const PostgrestException(
          message: 'secret database detail', code: '42501');
    await _open(tester, repository);
    await _fill(tester);
    await _submit(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('secret'), findsNothing);
    await _submit(tester);
    await tester.pumpAndSettle();
    expect(repository.saved, hasLength(2));
    expect(identical(repository.saved[0], repository.saved[1]), isTrue);
    await tester.enterText(find.byType(TextFormField).first, '12.35');
    await _submit(tester);
    await tester.pumpAndSettle();
    expect(repository.saved, hasLength(3));
    expect(repository.saved[2].id, isNot(repository.saved[0].id));
    expect(repository.saved[2].amount, 12.35);
  });

  testWidgets('signed-out and unsupported currency forms cannot submit',
      (tester) async {
    final repository = _Repository();
    await _open(tester, repository, user: null);
    expect(find.text('Please sign in to record a payment.'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await _open(tester, repository, currency: 'JPY');
    expect(find.text('This currency is not supported yet.'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(repository.saved, isEmpty);
  });
}
