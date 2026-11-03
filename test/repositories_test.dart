import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:split_it/core/services/cloud_db_service.dart';
import 'package:split_it/core/utils/money.dart';
import 'package:split_it/features/expenses/data/expenses_repository.dart';
import 'package:split_it/features/friends/data/friends_repository.dart';
import 'package:split_it/features/groups/data/groups_repository.dart';
import 'package:split_it/features/settle/data/settlements_repository.dart';
import 'package:split_it/shared/models/expense.dart';
import 'package:split_it/shared/models/friend.dart';
import 'package:split_it/shared/models/group.dart';
import 'package:split_it/shared/models/settlement.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _alice = '00000000-0000-0000-0000-000000000001';
const _bob = '00000000-0000-0000-0000-000000000002';
const _carol = '00000000-0000-0000-0000-000000000003';
const _outsider = '00000000-0000-0000-0000-000000000004';
const _group = '10000000-0000-0000-0000-000000000001';
const _expense = '20000000-0000-0000-0000-000000000001';
const _settlement = '30000000-0000-0000-0000-000000000001';
final _date = DateTime.utc(2026, 1, 2, 3, 4, 5);

Expense _newExpense({double amount = 10.01, Map<String, double>? split}) =>
    Expense(
      id: _expense,
      groupId: _group,
      description: 'Dinner',
      amount: amount,
      paidBy: _alice,
      date: _date,
      split: split ?? {_alice: 5.01, _bob: 5},
      imageUrl: 'receipts/test.jpg',
      createdBy: _alice,
    );

void main() {
  group('Money boundary', () {
    test('round trips exact cents, including the supported limit', () {
      for (final cents in [
        0,
        1,
        -1,
        29,
        1001,
        999999999999,
        CloudDbService.maxMinorUnits,
        -CloudDbService.maxMinorUnits
      ]) {
        expect(
            CloudDbService.toMinorUnits(CloudDbService.fromMinorUnits(cents)),
            cents);
      }
      expect(CloudDbService.maxMinorUnits, Money.maxMinorUnits);
      expect(CloudDbService.maxMinorUnits, 999999999999);
      expect(CloudDbService.toMinorUnits(0.1 + 0.2), 30);
    });

    test('rejects fractional cents, nonfinite values, and unsafe amounts', () {
      for (final amount in [
        1.001,
        double.nan,
        double.infinity,
        -double.infinity,
        (CloudDbService.maxMinorUnits + 1) / 100
      ]) {
        expect(() => CloudDbService.toMinorUnits(amount), throwsArgumentError);
      }
      for (final cents in [
        1.5,
        double.nan,
        double.infinity,
        CloudDbService.maxMinorUnits + 1
      ]) {
        expect(
            () => CloudDbService.fromMinorUnits(cents), throwsFormatException);
      }
    });
  });

  group('Supabase repositories', () {
    late HttpServer server;
    late SupabaseClient client;
    late List<({Uri uri, String method, dynamic body})> requests;
    dynamic response;
    late int apiCap;
    late bool ignoreCursor;
    late bool failAfterFirstPage;

    setUp(() async {
      requests = [];
      response = null;
      apiCap = 1000;
      ignoreCursor = false;
      failAfterFirstPage = false;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final text = await utf8.decoder.bind(request).join();
        requests.add((
          uri: request.uri,
          method: request.method,
          body: text.isEmpty ? null : jsonDecode(text)
        ));
        request.response.headers.contentType = ContentType.json;
        final query = request.uri.queryParameters;
        final order = query['order'];
        dynamic body = response;
        if (body is List && order != null) {
          final key = order.split('.').first;
          final filter = query[key];
          if (failAfterFirstPage && filter != null) {
            request.response.statusCode = 500;
            request.response.write(jsonEncode({'message': 'Page failed'}));
            await request.response.close();
            return;
          }
          var rows = body.cast<Map<String, dynamic>>().toList();
          if (!ignoreCursor && filter != null && filter.startsWith('gt.')) {
            rows = rows
                .where((row) =>
                    (row[key] as String).compareTo(filter.substring(3)) > 0)
                .toList();
          }
          rows.sort((a, b) {
            final compared = (a[key] as String).compareTo(b[key] as String);
            return order.split('.')[1] == 'desc' ? -compared : compared;
          });
          final requested = int.parse(query['limit'] ?? '1000');
          body = rows.take(requested < apiCap ? requested : apiCap).toList();
        }
        request.response.write(jsonEncode(body));
        await request.response.close();
      });
      client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false));
    });

    tearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    Future<void> signIn() async {
      final expiry =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
              1000;
      String part(Object value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      await client.auth.recoverSession(jsonEncode({
        'access_token': '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
            '${part({'sub': _alice, 'exp': expiry})}.test',
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'expires_at': expiry,
        'expires_in': 3600,
        'user': {
          'id': _alice,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'alice@example.com',
          'created_at': _date.toIso8601String()
        },
      }));
    }

    test('group reads retain all members while filtering membership', () async {
      response = [
        {
          'id': _group,
          'name': 'Trip',
          'description': null,
          'image_url': null,
          'created_by': _alice,
          'created_at': _date.toIso8601String(),
          'currency': 'USD',
          'member_ids': [_alice, _bob],
        }
      ];
      final groups = await GroupsRepository(client).getGroups(_alice);
      expect(groups.single.memberIds, [_alice, _bob]);
      expect(groups.single.createdAt, _date);
      expect(requests.first.uri.path, '/rest/v1/group_records');
      expect(
          requests.first.uri.queryParameters['member_ids'], 'cs.{"$_alice"}');
      expect(requests.first.uri.queryParameters['order'], startsWith('id.asc'));
      expect(requests.last.uri.queryParameters['id'], 'gt.$_group');
    });

    String id(int value) =>
        '50000000-0000-0000-0000-${value.toString().padLeft(12, '0')}';

    test('expenses paginate beyond page size under a smaller API cap',
        () async {
      apiCap = 7; // Below both the 200-row request and default Supabase cap.
      final manySplits = [
        for (var i = 1; i <= 1205; i++) {'user_id': id(i), 'amount_minor': 1},
      ];
      response = [
        for (var i = 1; i <= 205; i++)
          {
            'id': id(i),
            'group_id': _group,
            'description': 'Dinner $i',
            'amount_minor': i == 1 ? 1205 : 1,
            'paid_by': _alice,
            'expense_date': _date.toIso8601String(),
            'receipt_path': null,
            'created_by': _alice,
            'expense_splits': i == 1
                ? manySplits
                : [
                    {'user_id': _alice, 'amount_minor': 1}
                  ],
          },
      ];
      final expenses = await ExpensesRepository(client).getExpenses(_group);
      expect(expenses.length, 205);
      expect(expenses.map((e) => e.id), [for (var i = 205; i >= 1; i--) id(i)]);
      expect(expenses.last.split.length, 1205);
      expect(expenses.last.amount, 12.05);
      expect(requests.length, 31); // 30 nonempty pages and a final empty page.
      expect(requests.every((r) => r.uri.path == '/rest/v1/expense_records'),
          isTrue);
      expect(requests.last.uri.queryParameters['id'], 'gt.${id(205)}');
      response = (response as List).first;
      final detail = await ExpensesRepository(client).getExpenseById(id(1));
      expect(detail!.split.length, 1205);
      expect(requests.last.uri.path, '/rest/v1/expense_records');
    });

    test('settlements paginate full and short pages with ID date ties',
        () async {
      response = [
        for (var i = 1; i <= 1050; i++)
          {
            'id': id(i),
            'group_id': _group,
            'paid_by': _alice,
            'paid_to': _bob,
            'amount_minor': 1,
            'settled_at': _date.toIso8601String(),
            'note': null
          },
      ];
      final settlements =
          await SettlementsRepository(client).getSettlements(_group);
      expect(settlements.length, 1050);
      expect(settlements.first.id, id(1050));
      expect(settlements.last.id, id(1));
      expect(requests.length, 7); // 5 * 200 + 50 + empty; exceeds default cap.
      apiCap = 7;
      requests.clear();
      final capped = await SettlementsRepository(client).getSettlements(_group);
      expect(capped, settlements);
      expect(
          requests.length, 151); // Exact cap multiple still needs empty page.
    });

    test('groups and single group preserve uncapped member arrays', () async {
      apiCap = 3;
      final members = [for (var i = 1; i <= 1205; i++) id(i)];
      response = [
        for (var i = 1; i <= 205; i++)
          {
            'id': id(i),
            'name': 'Trip',
            'description': null,
            'image_url': null,
            'created_by': _alice,
            'created_at': _date.toIso8601String(),
            'currency': 'USD',
            'member_ids': i == 1 ? members : [_alice]
          },
      ];
      final groups = await GroupsRepository(client).getGroups(_alice);
      expect(groups.length, 205);
      expect(groups.first.id, id(205));
      expect(groups.last.memberIds, members);
      response = (response as List).first;
      final group = await GroupsRepository(client).getGroup(id(1));
      expect(group!.memberIds, members);
      expect(requests.last.uri.path, '/rest/v1/group_records');
    });

    test('friends and incoming requests also paginate below requested cap',
        () async {
      apiCap = 2;
      response = [
        for (var i = 1; i <= 9; i++)
          {
            'id': id(i),
            'display_name': 'Same name',
            'email': null,
            'avatar_url': null
          },
      ];
      final friends = await FriendsRepository(client).getFriends(_alice);
      expect(friends.map((f) => f.id), [for (var i = 1; i <= 9; i++) id(i)]);
      response = [
        for (var i = 1; i <= 9; i++)
          {
            'requester_id': id(i),
            'addressee_id': _alice,
            'display_name': 'Same name',
            'avatar_url': null,
            'created_at': _date.toIso8601String()
          },
      ];
      final pending = await FriendsRepository(client).getFriendRequests();
      expect(pending.map((p) => p.requesterId),
          [for (var i = 9; i >= 1; i--) id(i)]);
      expect(requests.last.uri.queryParameters['requester_id'], 'gt.${id(9)}');
    });

    test('pagination failures never return a partial ledger', () async {
      apiCap = 1;
      response = [
        {
          'id': id(1),
          'group_id': _group,
          'paid_by': _alice,
          'paid_to': _bob,
          'amount_minor': 1,
          'settled_at': _date.toIso8601String()
        },
        {
          'id': id(2),
          'group_id': _group,
          'paid_by': _alice,
          'paid_to': _bob,
          'amount_minor': 1,
          'settled_at': _date.toIso8601String()
        },
      ];
      failAfterFirstPage = true;
      await expectLater(SettlementsRepository(client).getSettlements(_group),
          throwsA(isA<PostgrestException>()));
      failAfterFirstPage = false;
      ignoreCursor = true;
      await expectLater(SettlementsRepository(client).getSettlements(_group),
          throwsFormatException);
    });

    test('group writes use the transactional RPCs', () async {
      final repo = GroupsRepository(client);
      final group = Group(
          id: _group,
          name: 'Trip',
          createdBy: _alice,
          createdAt: _date,
          memberIds: const [_alice, _bob]);
      await repo.createGroup(group);
      await repo.updateGroup(group);
      await repo.addMember(_group, _bob);
      expect(requests.map((r) => r.uri.path), [
        '/rest/v1/rpc/create_group',
        '/rest/v1/rpc/update_group',
        '/rest/v1/rpc/add_group_member',
      ]);
      expect(requests.first.body['p_member_ids'], [_alice, _bob]);
      expect(requests.last.body, {'p_group_id': _group, 'p_member_id': _bob});
    });

    test('expense writes send integer cents and UTC in one call', () async {
      await ExpensesRepository(client).saveExpense(_newExpense());
      expect(requests.single.uri.path, '/rest/v1/rpc/save_expense');
      expect(requests.single.body, {
        'p_id': _expense,
        'p_group_id': _group,
        'p_description': 'Dinner',
        'p_amount_minor': 1001,
        'p_paid_by': _alice,
        'p_expense_date': _date.toIso8601String(),
        'p_receipt_path': 'receipts/test.jpg',
        'p_created_by': _alice,
        'p_splits': [
          {'user_id': _alice, 'amount_minor': 501},
          {'user_id': _bob, 'amount_minor': 500}
        ],
      });
    });

    test('invalid expenses fail before networking', () async {
      final repo = ExpensesRepository(client);
      for (final expense in [
        _newExpense(amount: 0),
        _newExpense(amount: -1),
        _newExpense(amount: 1.001),
        _newExpense(split: {}),
        _newExpense(split: {_alice: 10}),
        _newExpense(split: {_alice: -1, _bob: 11.01}),
        _newExpense(split: {_alice: 5.005, _bob: 5.005}),
      ]) {
        await expectLater(repo.saveExpense(expense), throwsArgumentError);
      }
      expect(requests, isEmpty);
    });

    test('expense rows map splits, dates, and receipt paths', () async {
      response = {
        'id': _expense,
        'group_id': _group,
        'description': 'Dinner',
        'amount_minor': 1001,
        'paid_by': _alice,
        'expense_date': _date.toIso8601String(),
        'receipt_path': 'receipts/test.jpg',
        'created_by': _alice,
        'expense_splits': [
          {'user_id': _alice, 'amount_minor': 501},
          {'user_id': _bob, 'amount_minor': 500},
        ],
      };
      expect(await ExpensesRepository(client).getExpenseById(_expense),
          _newExpense());
    });

    test('incomplete expense splits are rejected instead of used as a ledger',
        () async {
      response = {
        'id': _expense,
        'group_id': _group,
        'description': 'Dinner',
        'amount_minor': 1001,
        'paid_by': _alice,
        'expense_date': _date.toIso8601String(),
        'receipt_path': null,
        'created_by': _alice,
        'expense_splits': [
          {'user_id': _alice, 'amount_minor': 501}
        ],
      };
      await expectLater(ExpensesRepository(client).getExpenseById(_expense),
          throwsFormatException);
    });

    test('settlements reject another payer and send own payment', () async {
      final repo = SettlementsRepository(client);
      final settlement = Settlement(
          id: _settlement,
          groupId: _group,
          paidBy: _alice,
          paidTo: _bob,
          amount: 5.01,
          date: _date,
          note: 'Cash');
      await expectLater(repo.saveSettlement(settlement), throwsStateError);
      expect(requests, isEmpty);
      await signIn();
      await repo.saveSettlement(settlement);
      expect(requests.single.uri.path, '/rest/v1/rpc/save_settlement');
      expect(requests.single.body['p_amount_minor'], 501);
      expect(requests.single.body['p_paid_by'], _alice);
      response = {
        'id': _settlement,
        'group_id': _group,
        'paid_by': _alice,
        'paid_to': _bob,
        'amount_minor': 501,
        'settled_at': _date.toIso8601String(),
        'note': 'Cash'
      };
      expect(await repo.getSettlementById(_settlement), settlement);
    });

    test('settlements reject self-payments and invalid cents', () async {
      final repo = SettlementsRepository(client);
      for (final amount in [0.0, -1.0, 1.001]) {
        await expectLater(
            repo.saveSettlement(Settlement(
                id: _settlement,
                groupId: _group,
                paidBy: _alice,
                paidTo: _bob,
                amount: amount,
                date: _date)),
            throwsArgumentError);
      }
      await expectLater(
          repo.saveSettlement(Settlement(
              id: _settlement,
              groupId: _group,
              paidBy: _alice,
              paidTo: _alice,
              amount: 1,
              date: _date)),
          throwsArgumentError);
      expect(requests, isEmpty);
    });

    test('friend requests only send email, never fake IDs or supplied names',
        () async {
      await FriendsRepository(client).addFriend(const Friend(
          id: 'placeholder',
          userId1: _alice,
          userId2: '  bob@example.com  ',
          friendName: 'Untrusted'));
      expect(requests.single.uri.path, '/rest/v1/rpc/add_friend_by_email');
      expect(requests.single.body, {'p_email': 'bob@example.com'});
    });

    test('invalid friend email fails before networking', () async {
      await expectLater(
          FriendsRepository(client).addFriend(const Friend(
              id: 'placeholder',
              userId1: _alice,
              userId2: _bob,
              friendName: 'Bob')),
          throwsArgumentError);
      expect(requests, isEmpty);
    });

    test('accepted friends and pending requests have separate mappings',
        () async {
      final repo = FriendsRepository(client);
      response = [
        {
          'id': _bob,
          'display_name': 'Bob',
          'email': 'bob@example.com',
          'avatar_url': null
        }
      ];
      final friends = await repo.getFriends(_alice);
      expect(friends.single.id, _bob);
      expect(friends.single.userId1, _alice);
      expect(friends.single.userId2, _bob);
      expect(friends.single.friendEmail, 'bob@example.com');
      expect(friends.single.balance, 0);
      response = [
        {
          'requester_id': _bob,
          'addressee_id': _alice,
          'display_name': 'Bob',
          'avatar_url': null,
          'created_at': _date.toIso8601String()
        }
      ];
      final pending = await repo.getFriendRequests();
      expect(pending.single.requesterId, _bob);
      expect(pending.single.addresseeId, _alice);
      expect(pending.single.createdAt, _date);
      response = null;
      await repo.respondToFriendRequest(_bob, accept: true);
      expect(requests.last.body, {'p_requester_id': _bob, 'p_accept': true});
      await repo.deleteFriend(friends.single);
      expect(requests.last.body, {'p_friend_id': _bob});
    });
  });

  // Opt-in: creates/stops/removes its OWN temporary PostgreSQL cluster. Requires
  // initdb, pg_ctl, and psql on PATH; never connects to an existing database.
  test('PostgreSQL schema, RPC security, and rollback integration', () async {
    final directory =
        await Directory.systemTemp.createTemp('split_it_rpc_test_');
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    var started = false;
    Future<void> command(String executable, List<String> arguments) async {
      final process = await Process.start(executable, arguments);
      final output = StringBuffer();
      final stdout =
          process.stdout.transform(utf8.decoder).listen(output.write);
      final stderr =
          process.stderr.transform(utf8.decoder).listen(output.write);
      await process.stdin.close();
      // Windows postgres inherits pg_ctl's pipe handles even with a log file.
      // Wait for pg_ctl itself, not EOF from the long-lived server process.
      final code = await process.exitCode.timeout(const Duration(seconds: 30),
          onTimeout: () {
        process.kill();
        throw StateError('$executable timed out');
      });
      await stdout.cancel();
      await stderr.cancel();
      expect(code, 0, reason: output.toString());
    }

    try {
      final data = '${directory.path}/data';
      await command('initdb', [
        '-D',
        data,
        '-U',
        'postgres',
        '-A',
        'trust',
        '--no-locale',
        '--encoding=UTF8'
      ]);
      await command('pg_ctl', [
        '-D',
        data,
        '-l',
        '${directory.path}/postgres.log',
        '-o',
        '-h 127.0.0.1 -p $port',
        '-w',
        'start'
      ]);
      started = true;
      final schema = await File('supabase/schema.sql').readAsString();
      final process = await Process.start('psql', [
        '-X',
        '--no-password',
        '-h',
        '127.0.0.1',
        '-p',
        '$port',
        '-U',
        'postgres',
        '-d',
        'postgres',
        '--set',
        'ON_ERROR_STOP=1'
      ]);
      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      process.stdin.write('$_bootstrap\n$schema\n'
          // Simulate the previous schema's column grant before rerunning.
          'grant update (display_name, avatar_url) on public.profiles to authenticated;\n'
          '$schema\n$_databaseChecks\n$_readViewChecks');
      await process.stdin.close();
      final code = await process.exitCode;
      expect(code, 0, reason: '${await stdout}\n${await stderr}');
    } finally {
      if (started) {
        await Process.run('pg_ctl',
            ['-D', '${directory.path}/data', '-m', 'immediate', '-w', 'stop']);
      }
      await directory.delete(recursive: true);
    }
  },
      skip: Platform.environment['SPLIT_IT_TEST_POSTGRES'] != 'true',
      timeout: const Timeout(Duration(minutes: 2)));
}

// Minimal Supabase auth stand-in, ONLY inside the disposable test cluster.
const _bootstrap = """
set client_encoding = 'UTF8';
create role anon;
create role authenticated;
create role service_role bypassrls;
create role supabase_auth_admin;
create schema auth;
grant usage on schema auth to authenticated;
create table auth.users (
  id uuid primary key, email text, email_confirmed_at timestamptz,
  raw_user_meta_data jsonb not null default '{}'::jsonb
);
grant usage on schema auth to supabase_auth_admin;
grant select, insert, update on auth.users to supabase_auth_admin;
-- Exercise the same nontruncating projection during missing-profile backfill.
insert into auth.users (id, email, raw_user_meta_data) values
  ('40000000-0000-0000-0000-000000000005', 'legacy@example.com',
   jsonb_build_object('display_name', repeat('L', 80), 'avatar_url', 'legacy.png'));
create function auth.uid() returns uuid language sql stable as
  'select nullif(current_setting(''request.jwt.claim.sub'', true), '''')::uuid';
create function auth.jwt() returns jsonb language sql stable as
  'select ''{}''::jsonb';
create publication supabase_realtime;
""";

const _profileMetadataChecks = '''
-- Auth's database role has no profile-write privileges. The restricted definer
-- trigger must perform this upsert in the same transaction as the Auth update.
set role supabase_auth_admin;
update auth.users set raw_user_meta_data = jsonb_build_object(
  'display_name', 'Alice Updated', 'avatar_url', 'https://example.com/alice.png',
  'unrelated', 'preserved') where id = '$_alice';
reset role;
do \$\$
declare
  invalid_name jsonb;
  metadata_before jsonb;
  profile_before public.profiles%rowtype;
begin
  assert (select display_name = repeat('L', 80) and avatar_url = 'legacy.png'
    from public.profiles where id = '40000000-0000-0000-0000-000000000005'), 'backfill uses full valid name';
  assert (select display_name = 'Alice Updated' and avatar_url = 'https://example.com/alice.png'
    from public.profiles where id = '$_alice'), 'Auth metadata update syncs both fields';
  assert (select raw_user_meta_data ->> 'unrelated' = 'preserved'
    from auth.users where id = '$_alice'), 'unrelated metadata preserved';
  select raw_user_meta_data into metadata_before from auth.users where id = '$_alice';
  select * into profile_before from public.profiles where id = '$_alice';
  for invalid_name in select value from jsonb_array_elements(
    jsonb_build_array('', '   ', repeat('x', 81), null, 42, '{}'::jsonb, '[]'::jsonb))
  loop
    begin
      update auth.users set raw_user_meta_data = metadata_before || jsonb_build_object(
        'display_name', invalid_name, 'avatar_url', 'should-not-commit.png') where id = '$_alice';
      raise exception 'Invalid updated name accepted: %', invalid_name;
    exception when invalid_parameter_value then null; end;
    assert (select raw_user_meta_data = metadata_before from auth.users where id = '$_alice'), 'invalid update rolls back Auth';
    assert (select p = profile_before from public.profiles p where id = '$_alice'), 'invalid update leaves entire profile unchanged';
    begin
      insert into auth.users (id, email, raw_user_meta_data) values
        ('40000000-0000-0000-0000-000000000001', 'invalid@example.com',
         jsonb_build_object('display_name', invalid_name));
      raise exception 'Invalid signup name accepted: %', invalid_name;
    exception when invalid_parameter_value then null; end;
    assert not exists (select 1 from auth.users where id = '40000000-0000-0000-0000-000000000001'), 'invalid signup rolls back Auth';
    assert not exists (select 1 from public.profiles where id = '40000000-0000-0000-0000-000000000001'), 'invalid signup creates no profile';
  end loop;
  -- A failure in the actual profile write, not just validation, must roll back Auth.
  alter table public.profiles add constraint test_profile_write_failure
    check (display_name <> 'Reject profile write');
  begin
    update auth.users set raw_user_meta_data = metadata_before ||
      '{"display_name":"Reject profile write","avatar_url":"should-not-commit.png"}'::jsonb
      where id = '$_alice';
    raise exception 'Injected profile-write failure did not fire';
  exception when check_violation then null; end;
  alter table public.profiles drop constraint test_profile_write_failure;
  assert (select raw_user_meta_data = metadata_before from auth.users where id = '$_alice'), 'profile failure rolls back Auth';
  assert (select p = profile_before from public.profiles p where id = '$_alice'), 'profile failure rolls back profile';
  -- Boundaries count Unicode codepoints, not UTF-8 bytes or UTF-16 units.
  insert into auth.users (id, email, raw_user_meta_data) values
    ('40000000-0000-0000-0000-000000000002', 'boundary@example.com',
     jsonb_build_object('display_name', '  ' || repeat('😀', 80) || '  ', 'avatar_url', 'before.png'));
  assert (select display_name = repeat('😀', 80) from public.profiles
    where id = '40000000-0000-0000-0000-000000000002'), 'signup trims without truncating Unicode';
  update auth.users set raw_user_meta_data = jsonb_build_object('display_name', 'Z', 'avatar_url', null)
    where id = '40000000-0000-0000-0000-000000000002';
  assert (select display_name = 'Z' and avatar_url is null from public.profiles
    where id = '40000000-0000-0000-0000-000000000002'), 'one-character name and explicit avatar clearing';
  update auth.users set raw_user_meta_data = jsonb_build_object('display_name', repeat('😀', 80))
    where id = '40000000-0000-0000-0000-000000000002';
  assert (select display_name = repeat('😀', 80) from public.profiles
    where id = '40000000-0000-0000-0000-000000000002'), 'update preserves all 80 Unicode characters';
  -- Repair a missing profile via a metadata update; preserve identity/created_at
  -- during ordinary upserts (covered by the full-row rollback assertions above).
  delete from public.profiles where id = '40000000-0000-0000-0000-000000000002';
  update auth.users set raw_user_meta_data = '{"display_name":"Restored"}'::jsonb
    where id = '40000000-0000-0000-0000-000000000002';
  assert (select display_name = 'Restored' from public.profiles
    where id = '40000000-0000-0000-0000-000000000002'), 'metadata update repairs missing profile';
  update auth.users set email = 'renamed@example.com' where id = '$_carol';
  assert (select display_name = 'renamed' from public.profiles where id = '$_carol'), 'missing-name fallback follows email changes';
  assert not has_function_privilege('authenticated', 'public._profile_metadata(jsonb,text)', 'execute'), 'projection helper private';
  assert not has_function_privilege('anon', 'public.handle_new_user()', 'execute'), 'trigger function private';
  assert not has_column_privilege('authenticated', 'public.profiles', 'display_name', 'update'), 'legacy name column grant revoked';
  assert not has_column_privilege('authenticated', 'public.profiles', 'avatar_url', 'update'), 'legacy avatar column grant revoked';
end \$\$;
set role authenticated;
select set_config('request.jwt.claim.sub', '$_alice', false);
do \$\$ begin
  begin
    update public.profiles set display_name = 'Divergent' where id = '$_alice';
    raise exception 'Direct profile update bypassed Auth';
  exception when insufficient_privilege then null; end;
end \$\$;
reset role;
''';

const _moneyBoundaryChecks = '''
do \$\$
declare too_large bigint;
begin
  perform public.save_expense('20000000-0000-0000-0000-000000000099', '$_group', 'Maximum',
    999999999999, '$_alice', now(), null, '$_alice',
    '[{"user_id":"$_alice","amount_minor":999999999999}]');
  perform public.save_settlement('30000000-0000-0000-0000-000000000099', '$_group',
    '$_alice', '$_bob', 999999999999, now(), null);
  for too_large in select unnest(array[1000000000000, 35184372088831]::bigint[])
  loop
    begin
      perform public.save_expense('20000000-0000-0000-0000-000000000099', '$_group', 'Too large',
        too_large, '$_alice', now(), null, '$_alice',
        jsonb_build_array(jsonb_build_object('user_id', '$_alice', 'amount_minor', too_large)));
      raise exception 'Oversized expense accepted';
    exception when invalid_parameter_value then null; end;
    begin
      perform public.save_settlement('30000000-0000-0000-0000-000000000099', '$_group',
        '$_alice', '$_bob', too_large, now(), null);
      raise exception 'Oversized settlement accepted';
    exception when invalid_parameter_value then null; end;
  end loop;
  begin
    perform public.save_expense('20000000-0000-0000-0000-000000000099', '$_group', 'Oversized split',
      999999999999, '$_alice', now(), null, '$_alice',
      '[{"user_id":"$_alice","amount_minor":1000000000000}]');
    raise exception 'Oversized split accepted';
  exception when invalid_parameter_value then null; end;
  assert (select amount_minor = 999999999999 from public.expenses
    where id = '20000000-0000-0000-0000-000000000099'), 'maximum expense saved and failed updates rolled back';
  assert (select amount_minor = 999999999999 from public.settlements
    where id = '30000000-0000-0000-0000-000000000099'), 'maximum payment saved and failed updates rolled back';
  delete from public.expenses where id = '20000000-0000-0000-0000-000000000099';
  delete from public.settlements where id = '30000000-0000-0000-0000-000000000099';
end \$\$;
''';

const _readViewChecks = '''
-- Trusted fixture setup, rolled back at the end. API-level caps are exercised
-- by the HTTP tests; these checks prove the real SQL aggregates and RLS.
begin;
insert into auth.users (id, email)
select md5('member-' || i)::uuid, 'member' || i || '@example.com'
from generate_series(1, 1205) i;
insert into public.groups (id, name, created_by)
values ('$_group', 'Many members', '$_alice');
insert into public.group_members (group_id, user_id)
select '$_group'::uuid, md5('member-' || i)::uuid from generate_series(1, 1205) i;
insert into public.group_members (group_id, user_id) values ('$_group', '$_bob');
insert into public.expenses (id, group_id, description, amount_minor, paid_by, created_by)
values ('$_expense', '$_group', 'Many splits', 1205, '$_alice', '$_alice');
insert into public.expense_splits (expense_id, user_id, amount_minor)
select '$_expense'::uuid, md5('member-' || i)::uuid, 1 from generate_series(1, 1205) i;
insert into public.settlements (id, group_id, paid_by, paid_to, amount_minor, created_by)
values ('$_settlement', '$_group', '$_alice', '$_bob', 999999999999, '$_alice');
do \$\$ begin
  begin
    update public.expenses set amount_minor = 1000000000000 where id = '$_expense';
    raise exception 'Expense table allowed oversized amount';
  exception when check_violation then null; end;
  begin
    update public.expense_splits set amount_minor = 1000000000000 where expense_id = '$_expense';
    raise exception 'Split table allowed oversized amount';
  exception when check_violation then null; end;
  begin
    update public.settlements set amount_minor = 1000000000000 where id = '$_settlement';
    raise exception 'Settlement table allowed oversized amount';
  exception when check_violation then null; end;
end \$\$;
set local role authenticated;
select set_config('request.jwt.claim.sub', '$_alice', true);
do \$\$ begin
  assert (select cardinality(member_ids) = 1207 from public.group_records
    where id = '$_group' limit 1), 'scalar members exceed default API row cap';
  assert (select jsonb_array_length(expense_splits) = 1205 from public.expense_records
    where id = '$_expense' limit 1), 'scalar splits exceed default API row cap';
  assert (select sum((s ->> 'amount_minor')::bigint) = 1205
    from public.expense_records e, jsonb_array_elements(e.expense_splits) s
    where e.id = '$_expense'), 'all split cents retained';
  assert not has_table_privilege('authenticated', 'public.expense_records', 'insert'), 'expense view read-only';
  assert not has_table_privilege('authenticated', 'public.group_records', 'update'), 'group view read-only';
  assert not has_table_privilege('anon', 'public.expense_records', 'select'), 'no anonymous view access';
end \$\$;
select set_config('request.jwt.claim.sub', '$_outsider', true);
do \$\$ begin
  assert (select count(*) = 0 from public.expense_records), 'expense view honors caller RLS';
  assert (select count(*) = 0 from public.group_records), 'group view honors caller RLS';
end \$\$;
rollback;
''';

const _databaseChecks = '''
insert into auth.users (id, email, email_confirmed_at) values
  ('$_alice', 'alice@example.com', now()),
  ('$_bob', 'bob@example.com', now()),
  ('$_carol', 'carol@example.com', now()),
  ('$_outsider', 'outsider@example.com', now());
$_profileMetadataChecks
-- Test-only fault injection forces failure AFTER the expense header update
-- and split deletion, proving the whole replacement rolls back.
alter table public.expense_splits add constraint test_reject_777
  check (amount_minor <> 777);
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '$_alice', true);
select public.add_friend_by_email(' BOB@example.com ');
select public.add_friend_by_email('bob@example.com');
select public.add_friend_by_email('nobody@example.com');
select public.add_friend_by_email('alice@example.com');
do \$\$ begin
  assert (select count(*) = 0 from public.friendships), 'outgoing target is private';
  assert (select count(*) = 0 from public.list_friends('$_alice')), 'pending is not accepted';
  assert (select count(*) = 0 from public.list_friend_requests()), 'outgoing target cannot be enumerated';
  begin
    perform public.respond_friend_request('$_alice', true);
    raise exception 'requester accepted own request';
  exception when sqlstate '22023' then null; end;
  begin
    insert into public.friendships (requester_id, addressee_id, status)
    values ('$_alice', '$_carol', 'accepted');
    raise exception 'direct accepted friendship insert succeeded';
  exception when insufficient_privilege then null; end;
  begin
    perform public.list_friends('$_bob');
    raise exception 'another user friend list exposed';
  exception when insufficient_privilege then null; end;
end \$\$;
select set_config('request.jwt.claim.sub', '$_bob', true);
select public.add_friend_by_email('alice@example.com');
do \$\$ begin
  assert (select count(*) = 0 from public.list_friends('$_bob')), 'reverse request must not accept';
  assert (select count(*) = 1 from public.friendships), 'no reversed duplicate';
  assert (select count(*) = 1 from public.list_friend_requests()), 'incoming request visible';
end \$\$;
select public.respond_friend_request('$_alice', true);
select set_config('request.jwt.claim.sub', '$_alice', true);
do \$\$ begin
  assert (select count(*) = 1 from public.list_friends('$_alice')
    where id = '$_bob' and email = 'bob@example.com'), 'accepted profile mapping';
  assert (select count(*) = 0 from public.list_friend_requests()), 'accepted leaves pending list';
end \$\$;
select public.create_group('$_group', 'Trip', null, null, 'USD', array['$_alice', '$_bob']::uuid[], '$_alice');
select public.update_group('$_group', 'Updated', null, null, 'USD', array['$_alice']::uuid[], '$_alice');
select public.add_group_member('$_group', '$_bob');
$_moneyBoundaryChecks
do \$\$ begin
  assert (select count(*) = 2 from public.group_members), 'no stale member removal or duplicate';
  assert (select role = 'owner' from public.group_members where user_id = '$_alice'), 'owner preserved';
  begin
    perform public.update_group('$_group', 'Should roll back', null, null, 'USD',
      array['$_carol']::uuid[], '$_alice');
    raise exception 'nonfriend added';
  exception when insufficient_privilege then null; end;
  assert (select name = 'Updated' from public.groups where id = '$_group'), 'group metadata rollback';
  begin
    perform public.create_group('10000000-0000-0000-0000-000000000002', 'Invalid',
      null, null, 'USD', array['$_outsider']::uuid[], '$_alice');
    raise exception 'invalid group creation succeeded';
  exception when insufficient_privilege then null; end;
  assert (select count(*) = 1 from public.groups), 'group creation rollback';
end \$\$;
select public.save_expense('$_expense', '$_group', 'Dinner', 1001, '$_alice', now(), null, '$_alice',
  '[{"user_id":"$_alice","amount_minor":501},{"user_id":"$_bob","amount_minor":500}]');
do \$\$ begin
  assert (select sum(amount_minor) = 1001 from public.expense_splits), 'exact cents';
  begin
    perform public.save_expense('$_expense', '$_group', 'Bad total', 1001, '$_alice', now(), null, '$_alice',
      '[{"user_id":"$_alice","amount_minor":1000}]');
    raise exception 'bad split total saved';
  exception when sqlstate '22023' then null; end;
  begin
    perform public.save_expense('$_expense', '$_group', 'Fraction', 1001, '$_alice', now(), null, '$_alice',
      '[{"user_id":"$_alice","amount_minor":500.5},{"user_id":"$_bob","amount_minor":500.5}]');
    raise exception 'fractional cents saved';
  exception when sqlstate '22023' then null; end;
  begin
    perform public.save_expense('$_expense', '$_group', 'Duplicate', 1001, '$_alice', now(), null, '$_alice',
      '[{"user_id":"$_alice","amount_minor":501},{"user_id":"$_alice","amount_minor":500}]');
    raise exception 'duplicate split saved';
  exception when sqlstate '22023' then null; end;
  begin
    perform public.save_expense('$_expense', '$_group', 'Outsider', 1001, '$_alice', now(), null, '$_alice',
      '[{"user_id":"$_outsider","amount_minor":1001}]');
    raise exception 'outsider split saved';
  exception when sqlstate '22023' then null; end;
  begin
    perform public.save_expense('$_expense', '$_group', 'Outsider payer', 1001, '$_outsider', now(), null, '$_alice',
      '[{"user_id":"$_alice","amount_minor":1001}]');
    raise exception 'outsider payer saved';
  exception when sqlstate '22023' then null; end;
  begin
    perform public.save_expense('$_expense', '$_group', 'Must roll back', 1001, '$_alice', now(), null, '$_alice',
      '[{"user_id":"$_alice","amount_minor":777},{"user_id":"$_bob","amount_minor":224}]');
    raise exception 'injected split constraint did not fail';
  exception when check_violation then null; end;
  assert (select description = 'Dinner' from public.expenses where id = '$_expense'), 'expense rollback';
  assert (select count(*) = 2 and sum(amount_minor) = 1001 from public.expense_splits), 'split rollback';
  begin
    delete from public.expense_splits where expense_id = '$_expense';
    raise exception 'direct split write succeeded';
  exception when insufficient_privilege then null; end;
  begin
    update public.expenses set amount_minor = 999 where id = '$_expense';
    raise exception 'direct expense write succeeded';
  exception when insufficient_privilege then null; end;
  begin
    perform public.update_group('$_group', 'Updated', null, null, 'EUR', array['$_alice']::uuid[], '$_alice');
    raise exception 'currency changed after expense';
  exception when sqlstate '22023' then null; end;
end \$\$;
-- Successful replacement removes all stale splits, and repeated saves are safe.
select public.save_expense('$_expense', '$_group', 'Replacement', 1001, '$_bob', now(), null, '$_alice',
  '[{"user_id":"$_bob","amount_minor":1001}]');
do \$\$ begin
  assert (select count(*) = 1 and sum(amount_minor) = 1001 from public.expense_splits), 'replace splits';
end \$\$;
select public.save_settlement('$_settlement', '$_group', '$_alice', '$_bob', 501, now(), 'Cash');
select public.save_settlement('$_settlement', '$_group', '$_alice', '$_bob', 502, now(), 'Updated');
select set_config('request.jwt.claim.sub', '$_bob', true);
do \$\$ begin
  begin
    perform public.save_settlement('$_settlement', '$_group', '$_alice', '$_bob', 999, now(), null);
    raise exception 'another payer recorded';
  exception when insufficient_privilege then null; end;
  begin
    perform public.save_settlement('$_settlement', '$_group', '$_bob', '$_alice', 999, now(), null);
    raise exception 'payment identity changed';
  exception when insufficient_privilege then null; end;
  delete from public.settlements where id = '$_settlement';
  assert (select amount_minor = 502 from public.settlements where id = '$_settlement'), 'other payer cannot delete';
  begin
    perform public.add_group_member('$_group', '$_carol');
    raise exception 'nonadmin added member';
  exception when insufficient_privilege then null; end;
  begin
    perform public.save_expense('$_expense', '$_group', 'Hijack', 1001, '$_bob', now(), null, '$_alice',
      '[{"user_id":"$_bob","amount_minor":1001}]');
    raise exception 'noncreator edited expense';
  exception when insufficient_privilege then null; end;
end \$\$;
select set_config('request.jwt.claim.sub', '$_outsider', true);
do \$\$ begin
  assert (select count(*) = 0 from public.groups), 'outsider groups private';
  assert (select count(*) = 0 from public.expenses), 'outsider expenses private';
  assert (select count(*) = 0 from public.expense_splits), 'outsider splits private';
  assert (select count(*) = 0 from public.settlements), 'outsider settlements private';
  begin
    perform public.save_expense('$_expense', '$_group', 'Hijack', 1001, '$_alice', now(), null, '$_outsider',
      '[{"user_id":"$_outsider","amount_minor":1001}]');
    raise exception 'outsider wrote expense';
  exception when insufficient_privilege then null; end;
  assert not has_function_privilege('anon', 'public.add_friend_by_email(text)', 'execute'), 'no anon RPC';
  assert not has_function_privilege('authenticated', 'public._add_group_members(uuid,uuid[])', 'execute'), 'helper private';
  assert not has_table_privilege('authenticated', 'public.friendships', 'insert'), 'no fake accepted friendships';
end \$\$;
select set_config('request.jwt.claim.sub', '$_alice', true);
select public.remove_friend('$_bob');
do \$\$ begin
  assert (select count(*) = 0 from public.list_friends('$_alice')), 'remove friend';
end \$\$;
rollback;
''';
