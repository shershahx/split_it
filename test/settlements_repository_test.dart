import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:split_it/core/services/financial_error.dart';
import 'package:split_it/core/utils/money.dart';
import 'package:split_it/features/auth/providers/auth_provider.dart';
import 'package:split_it/features/settle/data/settlements_repository.dart';
import 'package:split_it/features/settle/providers/settlements_provider.dart';
import 'package:split_it/shared/models/app_user.dart';
import 'package:split_it/shared/models/settlement.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _payer = '11111111-1111-4111-8111-111111111111';
const _group = '22222222-2222-4222-8222-222222222222';
const _recipient = '33333333-3333-4333-8333-333333333333';
const _id = '44444444-4444-4444-8444-444444444444';

Settlement _draft({
  String payer = _payer,
  String recipient = _recipient,
  double amount = 12.34,
  String? note = 'Bank transfer',
}) =>
    Settlement(
      id: _id,
      groupId: _group,
      paidBy: payer,
      paidTo: recipient,
      amount: amount,
      date: DateTime.utc(2026).toLocal(),
      note: note,
    );

Map<String, dynamic> _row([String id = _id]) => {
      'id': id,
      'group_id': _group,
      'paid_by': _payer,
      'paid_to': _recipient,
      'amount_minor': 1234,
      'settled_at': '2026-01-01T00:00:00Z',
      'note': 'Bank transfer',
      'created_by': _payer,
      'created_at': '2026-01-01T00:00:00Z',
    };

http.Response _json(Object? value, {int status = 200}) =>
    http.Response(jsonEncode(value), status,
        headers: {'content-type': 'application/json'});

Future<void> _session(SupabaseClient client, String id) async {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final token = '${encode({'alg': 'HS256'})}.${encode({
        'sub': id,
        'exp': 4102444800
      })}.test';
  await client.auth.setInitialSession(jsonEncode({
    'access_token': token,
    'refresh_token': 'test-refresh',
    'token_type': 'bearer',
    'user': {'id': id, 'email': 'test@example.com'},
  }));
}

void main() {
  late SupabaseClient client;
  late SettlementsRepository repository;
  late List<http.Request> requests;
  late http.Response Function(http.Request) respond;
  late Future<void> Function()? afterRequest;

  setUp(() async {
    requests = [];
    respond = (_) => _json([]);
    afterRequest = null;
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        final response = respond(request);
        await afterRequest?.call();
        return http.Response.bytes(
          response.bodyBytes,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }),
    );
    await _session(client, _payer);
    repository = SettlementsRepository(client);
  });
  tearDown(() async => client.dispose());

  test('legacy constructor and map round trip remain unchanged', () {
    final settlement = _draft();
    expect(Settlement.fromMap(settlement.toMap()), settlement);
    expect(settlement.toMap()['amount'], 12.34);
    expect(Settlement.fromSupabaseRow(_row()), settlement);
  });

  test('record uses exact integer cents and server-owned payer identity',
      () async {
    respond = (_) => _json(_id);
    await repository.saveSettlement(_draft());
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/rest/v1/rpc/record_settlement');
    expect(jsonDecode(requests.single.body), {
      'settlement_id': _id,
      'target_group_id': _group,
      'recipient_id': _recipient,
      'total_minor': 1234,
      'paid_at': '2026-01-01T00:00:00.000Z',
      'settlement_note': 'Bank transfer',
    });
  });

  test('retry sends identical semantic payload and stable ID', () async {
    respond = (_) => _json(_id);
    final draft = _draft();
    await repository.saveSettlement(draft);
    await repository.saveSettlement(draft);
    expect(requests[0].body, requests[1].body);
  });

  test('cent round trips include the upper supported monetary boundary',
      () async {
    respond = (_) => _json(_id);
    for (final minor in [
      1,
      29,
      101,
      Money.maxMinorUnits - 1,
      Money.maxMinorUnits,
    ]) {
      await repository
          .saveSettlement(_draft(amount: Money.fromMinorUnits(minor)));
      expect(jsonDecode(requests.last.body)['total_minor'], minor);
    }
  });

  test(
      'invalid amounts, spoof payer, self recipient and long note stop locally',
      () async {
    for (final draft in [
      _draft(payer: _recipient),
      _draft(recipient: _payer),
      _draft(recipient: 'not-a-uuid'),
      _draft(note: 'x' * 301),
      for (final amount in [
        0.0,
        -1.0,
        double.nan,
        double.infinity,
        1.001,
        45035996273705.0
      ])
        _draft(amount: amount),
    ]) {
      await expectLater(
          repository.saveSettlement(draft), throwsA(isA<FinancialFailure>()));
    }
    expect(requests, isEmpty);
  });

  test('history has deterministic paging with twenty plus sentinel', () async {
    respond = (_) => _json(List.generate(21, (index) => _row('$index')));
    final page = await repository.getSettlementPage(_group, page: 2);
    expect(page.settlements, hasLength(20));
    expect(page.hasNext, isTrue);
    expect(requests.single.url.queryParameters, containsPair('offset', '40'));
    expect(requests.single.url.queryParameters, containsPair('limit', '21'));
    expect(requests.single.url.queryParameters,
        containsPair('group_id', 'eq.$_group'));
    expect(requests.single.url.queryParameters,
        containsPair('order', 'settled_at.desc.nullslast,id.desc.nullslast'));
    respond = (_) => _json([_row()]);
    expect((await repository.getSettlementPage(_group)).hasNext, isFalse);
    await expectLater(
        repository.getSettlementPage(_group, page: -1), throwsArgumentError);
  });

  test('detail uses single RLS-filtered query and permits missing record',
      () async {
    respond = (_) => _json(_row());
    expect(await repository.getSettlementById(_id), _draft());
    expect(requests.single.url.queryParameters['id'], 'eq.$_id');
    respond = (_) => _json(null);
    expect(await repository.getSettlementById(_id), isNull);
  });

  test('delete uses guarded server workflow, not direct table delete',
      () async {
    respond = (_) => http.Response('', 204);
    await repository.deleteSettlement(_draft());
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/rest/v1/rpc/delete_settlement');
    expect(jsonDecode(requests.single.body), {'target_settlement_id': _id});
  });

  test('RLS failures propagate for reads and mutations without false success',
      () async {
    respond = (_) =>
        _json({'code': '42501', 'message': 'secret SQL detail'}, status: 403);
    for (final operation in [
      () => repository.saveSettlement(_draft()),
      () => repository.deleteSettlement(_draft()),
      () => repository.getSettlementPage(_group),
      () => repository.getSettlementById(_id),
    ]) {
      await expectLater(operation(), throwsA(isA<PostgrestException>()));
    }
    expect(
        financialErrorMessage(const PostgrestException(
            code: '42501', message: 'secret SQL detail')),
        isNot(contains('secret')));
  });

  test('in-flight account change rejects reads and mutation success', () async {
    for (final operation in [
      () => repository.getSettlementPage(_group),
      () => repository.getSettlementById(_id),
      () => repository.saveSettlement(_draft()),
      () => repository.deleteSettlement(_draft()),
    ]) {
      await _session(client, _payer);
      respond = (request) => request.url.path.endsWith('/settlements')
          ? _json(
              request.url.queryParameters.containsKey('id') ? _row() : [_row()])
          : _json(_id);
      afterRequest = () => _session(client, _recipient);
      await expectLater(operation(), throwsA(isA<FinancialFailure>()));
    }
  });

  test('signed-out calls never reach network', () async {
    final signedOut = SupabaseClient('https://example.supabase.co', 'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient:
            MockClient((_) async => throw StateError('Unexpected HTTP')));
    addTearDown(signedOut.dispose);
    final repo = SettlementsRepository(signedOut);
    for (final operation in [
      () => repo.getSettlementPage(_group),
      () => repo.getSettlementById(_id),
      () => repo.saveSettlement(_draft()),
      () => repo.deleteSettlement(_draft()),
    ]) {
      await expectLater(operation(), throwsA(isA<FinancialFailure>()));
    }
  });

  test('provider pages reset and previews clear on account change', () async {
    final user = StateProvider<AppUser?>((ref) => const AppUser(uid: _payer));
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) => ref.watch(user)),
      settlementsRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    final pageSub =
        container.listen(settlementPageProvider(_group), (_, __) {});
    final previewSub =
        container.listen(settlementsProvider(_group), (_, __) {});
    addTearDown(pageSub.close);
    addTearDown(previewSub.close);
    respond = (_) => _json([_row()]);
    expect(
        await container.read(settlementsProvider(_group).future), hasLength(1));
    await container.read(settlementPageProvider(_group).future);
    container.read(settlementsPageIndexProvider(_group).notifier).state = 3;
    await container.read(settlementPageProvider(_group).future);
    container.read(user.notifier).state = const AppUser(uid: _recipient);
    expect(container.read(settlementsPageIndexProvider(_group)), 0);
    await container.read(settlementPageProvider(_group).future);
    final before = requests.length;
    container.read(user.notifier).state = null;
    expect(await container.read(settlementsProvider(_group).future), isEmpty);
    expect(
        (await container.read(settlementPageProvider(_group).future))
            .settlements,
        isEmpty);
    expect(requests, hasLength(before));
  });
}
