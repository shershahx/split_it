import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:split_it/core/services/financial_error.dart';
import 'package:split_it/core/utils/money.dart';
import 'package:split_it/features/expenses/data/expenses_repository.dart';
import 'package:split_it/shared/models/expense.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _other = '22222222-2222-4222-8222-222222222222';
const _group = '33333333-3333-4333-8333-333333333333';
const _expense = '44444444-4444-4444-8444-444444444444';

Map<String, dynamic> _row({String id = _expense}) => {
      'id': id,
      'group_id': _group,
      'description': 'Lunch',
      'amount_minor': 1001,
      'paid_by': _owner,
      'expense_date': '2026-01-01T00:00:00Z',
      'receipt_path': null,
      'created_by': _owner,
      'groups': {'currency': 'PKR'},
    };

Expense _draft(
        {String creator = _owner,
        double amount = 10.01,
        Map<String, double>? split}) =>
    Expense(
      id: _expense,
      groupId: _group,
      description: ' Lunch ',
      amount: amount,
      paidBy: _owner,
      date: DateTime.utc(2026),
      createdBy: creator,
      currency: 'PKR',
      split: split ??
          Expense.splitEqually(amount: amount, memberIds: [_owner, _other]),
    );

void main() {
  late SupabaseClient client;
  late ExpensesRepository repository;
  late List<http.Request> requests;
  late http.Response Function(http.Request) respond;

  http.Response json(Object? value, {int status = 200}) =>
      http.Response(jsonEncode(value), status,
          headers: {'content-type': 'application/json'});

  setUp(() async {
    requests = [];
    respond = (_) => json([]);
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        final response = respond(request);
        return http.Response.bytes(response.bodyBytes, response.statusCode,
            headers: response.headers, request: request);
      }),
    );
    await client.auth.setInitialSession(jsonEncode({
      'access_token': 'test-token',
      'token_type': 'bearer',
      'user': {'id': _owner},
    }));
    repository = ExpensesRepository(client);
  });
  tearDown(() async => client.dispose());

  test('expense save is one atomic RPC with exact integer splits', () async {
    respond = (_) => json(_expense);
    final draft = _draft();
    await repository.saveExpense(draft);
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/rest/v1/rpc/create_expense');
    final body = jsonDecode(requests.single.body) as Map;
    expect(body['expense_id'], _expense);
    expect(body['target_group_id'], _group);
    expect(body['total_minor'], 1001);
    expect(body['expense_description'], 'Lunch');
    expect(body['spent_at'], '2026-01-01T00:00:00.000Z');
    expect(body.containsKey('created_by'), isFalse);
    expect(body['splits'], [
      {'user_id': _owner, 'amount_minor': 501},
      {'user_id': _other, 'amount_minor': 500},
    ]);
    await repository.saveExpense(draft);
    expect(requests.last.body, requests.first.body);
  });

  test(
      'spoofed creator, zero/fractional amounts and invalid splits stop locally',
      () async {
    for (final draft in [
      _draft(creator: _other),
      _draft(amount: 0),
      _draft(amount: 1.001),
      _draft(split: {_owner: 10}),
      _draft(split: {_owner: -1, _other: 11.01}),
    ]) {
      await expectLater(
          repository.saveExpense(draft),
          throwsA(anyOf(
            isA<FinancialFailure>(),
            isA<ArgumentError>(),
          )));
    }
    expect(requests, isEmpty);
  });

  test('list loads one bounded group page without every allocation', () async {
    respond = (_) => json(List.generate(21, (i) => _row(id: '$i')));
    final page = await repository.getExpenses(_group, page: 1);
    expect(page.expenses, hasLength(20));
    expect(page.hasNext, isTrue);
    expect(page.expenses.first.currency, 'PKR');
    final params = requests.single.url.queryParameters;
    expect(params['group_id'], 'eq.$_group');
    expect(params['offset'], '20');
    expect(params['limit'], '21');
    expect(params['order'], 'expense_date.desc.nullslast,id.desc.nullslast');
    expect(params['select'], isNot(contains('expense_splits')));
  });

  test('single expense loads every split and validates total', () async {
    respond = (request) => request.url.path.endsWith('/expenses')
        ? json({
            ..._row(),
            'split_count': [
              {'count': 2}
            ]
          })
        : json([
            {'user_id': _owner, 'amount_minor': 501},
            {'user_id': _other, 'amount_minor': 500},
          ]);
    final expense = (await repository.getExpenseById(_expense))!;
    expect(expense.split, {_owner: 5.01, _other: 5});
    expect(expense.currency, 'PKR');
    expect(requests.last.url.queryParameters['expense_id'], 'eq.$_expense');
  });

  test('split download follows actual row counts under smaller server cap',
      () async {
    respond = (request) {
      if (request.url.path.endsWith('/expenses')) {
        return json({
          ..._row(),
          'split_count': [
            {'count': 2}
          ]
        });
      }
      return json([
        request.url.queryParameters['offset'] == '0'
            ? {'user_id': _owner, 'amount_minor': 501}
            : {'user_id': _other, 'amount_minor': 500}
      ]);
    };
    expect((await repository.getExpenseById(_expense))!.split, hasLength(2));
    expect(requests.last.url.queryParameters['offset'], '1');
  });

  test('incomplete splits cannot be displayed as a complete expense', () async {
    respond = (request) => request.url.path.endsWith('/expenses')
        ? json({
            ..._row(),
            'split_count': [
              {'count': 2}
            ]
          })
        : json([]);
    await expectLater(
        repository.getExpenseById(_expense), throwsA(isA<FinancialFailure>()));
  });

  test('inconsistent persisted split total is rejected', () async {
    respond = (request) => request.url.path.endsWith('/expenses')
        ? json({
            ..._row(),
            'split_count': [
              {'count': 1}
            ]
          })
        : json([
            {'user_id': _owner, 'amount_minor': 1000}
          ]);
    await expectLater(repository.getExpenseById(_expense), throwsArgumentError);
  });

  test('balances use complete server ledger RPC, not a page of expenses',
      () async {
    respond = (_) => json({
          'balances': [
            {'user_id': _owner, 'balance_minor': 500},
            {'user_id': _other, 'balance_minor': -500},
          ]
        });
    expect(
        await repository.getGroupBalances(_group), {_owner: 500, _other: -500});
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/rest/v1/rpc/get_group_balances');
    expect(jsonDecode(requests.single.body), {'target_group_id': _group});
  });

  test('non-conserving or duplicate balance output fails visibly', () async {
    respond = (_) => json({
          'balances': [
            {'user_id': _owner, 'balance_minor': 1},
          ]
        });
    await expectLater(
        repository.getGroupBalances(_group), throwsA(isA<FinancialFailure>()));
    respond = (_) => json({
          'balances': [
            {'user_id': _owner, 'balance_minor': 0},
            {'user_id': _owner, 'balance_minor': 0},
          ]
        });
    await expectLater(
        repository.getGroupBalances(_group), throwsA(isA<FinancialFailure>()));
  });

  test('delete uses authorized RPC, not multiple direct table writes',
      () async {
    respond = (_) => http.Response('', 204);
    await repository.deleteExpense(_draft());
    expect(requests.single.url.path, '/rest/v1/rpc/delete_expense');
    expect(jsonDecode(requests.single.body), {'target_expense_id': _expense});
  });

  test('permission failures propagate and UI error hides server internals',
      () async {
    respond = (_) =>
        json({'code': '42501', 'message': 'private SQL detail'}, status: 403);
    try {
      await repository.saveExpense(_draft());
      fail('Expected permission failure');
    } on PostgrestException catch (error) {
      expect(financialErrorMessage(error), isNot(contains('private')));
      expect(financialErrorMessage(error), contains('permission'));
    }
  });

  test('exact amount entry rejects ambiguous or nonfinite formats', () {
    expect(Money.parseAmount(' 10.01 '), 1001);
    expect(Money.parseAmount('1.'), 100);
    expect(Money.parseAmount('0.01'), 1);
    for (final input in [
      '',
      '.',
      '-1',
      'NaN',
      'Infinity',
      '1e3',
      '1,000',
      '1.001'
    ]) {
      expect(() => Money.parseAmount(input), throwsArgumentError);
    }
    expect(Money.formatMinorUnits(-1), '-0.01');
    expect(Money.formatMinorUnits(1001), '10.01');
  });
}
