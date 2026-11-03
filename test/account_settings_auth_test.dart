import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:split_it/features/auth/data/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _id = '00000000-0000-0000-0000-000000000001';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late AuthService service;
  late List<({Uri uri, String method, Map<String, dynamic> body})> requests;
  late String metadataName;
  late bool failUpdate;
  late bool unexpectedUser;

  Map<String, dynamic> user() => {
        'id': _id,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'alice@example.com',
        'created_at': '2026-01-01T00:00:00Z',
        'user_metadata': {'display_name': metadataName, 'other': 'preserved'},
      };

  setUp(() async {
    metadataName = 'Alice';
    failUpdate = false;
    unexpectedUser = false;
    requests = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final text = await utf8.decoder.bind(request).join();
      final body = text.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(text) as Map<String, dynamic>;
      requests.add((uri: request.uri, method: request.method, body: body));
      request.response.headers.contentType = ContentType.json;
      Object result;
      if (request.uri.path != '/auth/v1/user' || request.method != 'PUT') {
        request.response.statusCode = 403;
        result = {'message': 'Direct profile writes are not permitted'};
      } else if (failUpdate) {
        request.response.statusCode = 400;
        result = {'msg': 'Database error updating user'};
      } else {
        metadataName = (body['data'] as Map)['display_name'] as String;
        result = {
          ...user(),
          if (unexpectedUser) 'id': '00000000-0000-0000-0000-000000000002',
        };
      }
      request.response.write(jsonEncode(result));
      await request.response.close();
    });
    client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    final expiry =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000;
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    await client.auth.recoverSession(jsonEncode({
      'access_token': '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
          '${part({'sub': _id, 'exp': expiry})}.test',
      'refresh_token': 'test-refresh',
      'token_type': 'bearer',
      'expires_at': expiry,
      'expires_in': 3600,
      'user': user(),
    }));
    service = AuthService(client);
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test('trimmed name uses one Auth update and no direct profile write',
      () async {
    final saved = await service.updateDisplayName('  Bob  ');
    expect(saved.displayName, 'Bob');
    expect(metadataName, 'Bob');
    expect(requests, hasLength(1));
    expect(requests.single.method, 'PUT');
    expect(requests.single.uri.path, '/auth/v1/user');
    expect(requests.single.body['data'], {'display_name': 'Bob'});
    expect(client.auth.currentUser!.userMetadata!['other'], 'preserved');
  });

  test('validates 1..80 Unicode code points before any writes', () async {
    for (final invalid in [
      '',
      '   ',
      List.filled(81, 'a').join(),
      List.filled(81, '😀').join(),
    ]) {
      await expectLater(
          service.updateDisplayName(invalid), throwsA(isA<AuthException>()));
    }
    expect(requests, isEmpty);
    for (final name in ['😀', List.filled(80, '😀').join()]) {
      expect((await service.updateDisplayName('  $name  ')).displayName, name);
    }
    expect(requests, hasLength(2));
    expect(requests.every((r) => r.uri.path == '/auth/v1/user'), isTrue);
  });

  test('Auth failure propagates without a rollback or profile request',
      () async {
    failUpdate = true;
    await expectLater(
      service.updateDisplayName('Bob'),
      throwsA(isA<AuthException>()
          .having((e) => e.message, 'message', 'Database error updating user')),
    );
    expect(metadataName, 'Alice');
    expect(client.auth.currentUser!.userMetadata!['display_name'], 'Alice');
    expect(requests, hasLength(1));
    expect(requests.single.uri.path, '/auth/v1/user');
  });

  test('unexpected Auth user is rejected without compensating writes',
      () async {
    unexpectedUser = true;
    await expectLater(
      service.updateDisplayName('Bob'),
      throwsA(isA<AuthException>().having((e) => e.message, 'message',
          'Profile update did not return the expected user.')),
    );
    expect(requests, hasLength(1));
  });

  test('signed-out update is rejected before any request', () async {
    final signedOutClient = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    try {
      await expectLater(
        AuthService(signedOutClient).updateDisplayName('Bob'),
        throwsA(isA<AuthException>().having(
            (e) => e.message, 'message', 'Sign in before updating your name.')),
      );
      expect(requests, isEmpty);
    } finally {
      await signedOutClient.dispose();
    }
  });
}
