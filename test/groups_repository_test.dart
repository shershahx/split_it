import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:split_it/core/services/cloud_db_service.dart';
import 'package:split_it/features/groups/data/groups_repository.dart';
import 'package:split_it/shared/models/group.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '11111111-1111-4111-8111-111111111111';
const _groupId = '22222222-2222-4222-8222-222222222222';

Map<String, dynamic> _groupRow([String id = _groupId]) => {
      'id': id,
      'name': 'Trip',
      'description': null,
      'image_url': null,
      'currency': 'PKR',
      'created_by': _userId,
      'created_at': '2026-01-01T00:00:00Z',
      'group_members': [
        {'count': 2},
      ],
    };

http.Response _json(Object? value, {int status = 200}) =>
    http.Response(jsonEncode(value), status,
        headers: {'content-type': 'application/json'});

void main() {
  late SupabaseClient client;
  late GroupsRepository repository;
  late List<http.Request> requests;
  late http.Response Function(http.Request) respond;
  late Future<void> Function(http.Request)? afterRequest;

  setUp(() async {
    requests = [];
    respond = (_) => _json([]);
    afterRequest = null;
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        final response = respond(request);
        await afterRequest?.call(request);
        return http.Response.bytes(
          response.bodyBytes,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }),
    );
    // Local fixture only: never sent to a real Supabase project.
    String encode(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token = '${encode({'alg': 'HS256'})}.${encode({
          'sub': _userId,
          'exp': 4102444800
        })}.test';
    await client.auth.setInitialSession(jsonEncode({
      'access_token': token,
      'refresh_token': 'test-refresh',
      'token_type': 'bearer',
      'user': {'id': _userId, 'email': 'owner@example.com'},
    }));
    repository = GroupsRepository(client);
  });

  tearDown(() async => client.dispose());

  test('group drafts use UUIDs and database-owned membership fields', () {
    final group = Group.create(name: ' Trip ', createdBy: _userId);
    expect(
        group.id,
        matches(RegExp(
            r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$')));
    expect(group.name, 'Trip');
    expect(
        group.toMap().keys,
        unorderedEquals([
          'id',
          'name',
          'description',
          'image_url',
          'created_by',
          'currency'
        ]));
  });

  test('summaries decode a count without downloading member profiles', () {
    final group = Group.fromMap(_groupRow());
    expect(group.memberCount, 2);
    expect(group.members, isEmpty);
    expect(group.currency, 'PKR');
  });

  test('group list is server ordered with a bounded lookahead', () async {
    respond = (_) => _json(List.generate(21, (index) => _groupRow('$index')));
    final page = await repository.getGroups(page: 2);
    expect(page.groups, hasLength(20));
    expect(page.hasNext, isTrue);
    final params = requests.single.url.queryParameters;
    expect(params['offset'], '40');
    expect(params['limit'], '21');
    expect(params['order'], 'created_at.desc.nullslast,id.asc.nullslast');
    expect(params['select'], contains('group_members(count)'));
  });

  test('last page has no next page', () async {
    respond = (_) => _json([_groupRow()]);
    final page = await repository.getGroups();
    expect(page.groups, hasLength(1));
    expect(page.hasNext, isFalse);
  });

  test('create uses INSERT without RETURNING or client-controlled roles',
      () async {
    respond = (_) => http.Response('', 201);
    await repository.createGroup(
      Group.create(name: 'Trip', createdBy: _userId, currency: 'PKR'),
    );
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/rest/v1/groups');
    expect(requests.single.url.queryParameters.containsKey('select'), isFalse);
    expect(requests.single.headers['Prefer'],
        isNot(contains('return=representation')));
    final body = jsonDecode(requests.single.body) as Map;
    expect(body['created_by'], _userId);
    expect(body.containsKey('memberIds'), isFalse);
    expect(body.containsKey('role'), isFalse);
  });

  test('invalid or impersonated drafts never reach the network', () async {
    for (final group in [
      Group.create(name: '', createdBy: _userId),
      Group.create(name: 'x' * 101, createdBy: _userId),
      Group.create(name: 'Trip', createdBy: 'someone-else'),
      Group.create(name: 'Trip', createdBy: _userId, description: 'x' * 501),
      Group.create(name: 'Trip', createdBy: _userId, currency: 'JPY'),
    ]) {
      await expectLater(
          repository.createGroup(group), throwsA(isA<GroupFailure>()));
    }
    expect(requests, isEmpty);
  });

  test('detail reads membership in batches and maps profile names and roles',
      () async {
    respond = (request) {
      if (request.url.path.endsWith('/groups')) {
        return _json({
          ..._groupRow(),
          'group_members': [
            {'count': 101}
          ],
        });
      }
      final offset = request.url.queryParameters['offset'];
      if (offset == '0') {
        return _json(List.generate(
            100,
            (index) => {
                  'user_id': '$index',
                  'role': index == 0 ? 'owner' : 'member',
                  'profiles': {'display_name': 'Person $index'},
                }));
      }
      return _json([
        {
          'user_id': 'last',
          'role': 'member',
          'profiles': {'display_name': 'Last person'},
        },
      ]);
    };
    final group = (await repository.getGroup(_groupId))!;
    expect(group.members, hasLength(101));
    expect(group.memberIds, hasLength(101));
    expect(group.members.first.canInvite, isTrue);
    expect(group.members.last.displayName, 'Last person');
    expect(requests[1].url.queryParameters['limit'], '100');
    expect(requests[2].url.queryParameters['offset'], '100');
    expect(requests.first.url.queryParameters['id'], 'eq.$_groupId');
  });

  test('server row cap does not silently truncate membership', () async {
    respond = (request) {
      if (request.url.path.endsWith('/groups')) return _json(_groupRow());
      final offset = request.url.queryParameters['offset'];
      return _json([
        {
          'user_id': offset == '0' ? 'first' : 'second',
          'role': 'member',
          'profiles': {'display_name': 'Person'},
        },
      ]);
    };
    expect((await repository.getGroup(_groupId))!.members, hasLength(2));
    expect(requests[2].url.queryParameters['offset'], '1');
  });

  test('incomplete membership fails visibly rather than losing participants',
      () async {
    respond = (request) =>
        request.url.path.endsWith('/groups') ? _json(_groupRow()) : _json([]);
    await expectLater(
        repository.getGroup(_groupId), throwsA(isA<GroupFailure>()));
  });

  test('membership download stops if the signed-in account changes', () async {
    respond = (request) => request.url.path.endsWith('/groups')
        ? _json(_groupRow())
        : _json([
            {'user_id': 'first', 'role': 'member', 'profiles': null},
          ]);
    afterRequest = (request) async {
      if (request.url.path.endsWith('/group_members')) {
        await client.auth.setInitialSession(jsonEncode({
          'access_token': 'other-test-token',
          'token_type': 'bearer',
          'user': {'id': 'other-account'},
        }));
      }
    };
    await expectLater(
        repository.getGroup(_groupId), throwsA(isA<GroupFailure>()));
    expect(requests, hasLength(2));
  });

  test('inaccessible group does not fetch membership', () async {
    respond = (_) => _json(null);
    expect(await repository.getGroup(_groupId), isNull);
    expect(requests, hasLength(1));
  });

  test('invitation normalizes email and uses server workflow', () async {
    respond = (_) => _json('invite-id');
    await repository.inviteMember(_groupId, '  Friend@Example.COM ');
    expect(requests.single.url.path, '/rest/v1/rpc/send_group_invite');
    expect(jsonDecode(requests.single.body), {
      'target_group_id': _groupId,
      'invite_email': 'friend@example.com',
    });
  });

  test('bad invitation email never reaches the network', () async {
    await expectLater(
      repository.inviteMember(_groupId, 'not-an-email'),
      throwsA(isA<GroupFailure>()),
    );
    expect(requests, isEmpty);
  });

  test('invitation inbox uses bounded server preview RPC', () async {
    respond = (_) => _json([
          {
            'id': 'invite',
            'group_name': 'Trip',
            'invited_by_name': 'Owner',
            'expires_at': '2026-12-01T00:00:00Z',
          },
        ]);
    final invites = await repository.getInvites(page: 3);
    expect(invites.single.groupName, 'Trip');
    expect(requests.single.url.path, '/rest/v1/rpc/list_my_group_invites');
    expect(jsonDecode(requests.single.body), {'page_offset': 60});
  });

  test('accept and decline never write memberships directly', () async {
    respond = (_) => _json(_groupId);
    expect(await repository.acceptInvite('invite-id'), _groupId);
    await repository.declineInvite('other-id');
    expect(requests.map((request) => request.url.path), [
      '/rest/v1/rpc/accept_group_invite',
      '/rest/v1/rpc/decline_group_invite',
    ]);
    expect(jsonDecode(requests.first.body), {'invite_id': 'invite-id'});
  });

  test('signed-out requests stop before network access', () async {
    final signedOut = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient:
          MockClient((_) async => throw StateError('Unexpected request')),
    );
    addTearDown(signedOut.dispose);
    await expectLater(
      GroupsRepository(signedOut).getGroups(),
      throwsA(isA<GroupFailure>()),
    );
  });

  test('negative page offsets are rejected', () async {
    await expectLater(repository.getGroups(page: -1), throwsArgumentError);
    await expectLater(repository.getInvites(page: -1), throwsArgumentError);
    expect(requests, isEmpty);
  });

  test('server failures propagate; no false create success', () async {
    respond = (_) => _json({
          'code': '42501',
          'message': 'private SQL detail',
        }, status: 403);
    await expectLater(
      repository.createGroup(Group.create(name: 'Trip', createdBy: _userId)),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('error display hides raw database internals', () {
    const error = PostgrestException(
      message: 'secret SQL detail',
      code: '23514',
      details: 'private',
    );
    expect(groupErrorMessage(error), isNot(contains('secret')));
    expect(
      groupErrorMessage(
          const PostgrestException(message: 'private', code: 'PGRST202')),
      contains('migration'),
    );
  });

  test('legacy data writes and deletes cannot claim success', () async {
    final legacy = CloudDbService();
    await expectLater(
        legacy.upsertObject('Expense', []), throwsUnsupportedError);
    await expectLater(
        legacy.deleteObject('Expense', []), throwsUnsupportedError);
  });
}
