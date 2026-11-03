import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

/// Stores the serialized Supabase session in platform-protected storage.
class SecureAuthStorage extends LocalStorage {
  const SecureAuthStorage();

  static const _sessionKey = 'split_it.auth.session';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      await _secureStorage.containsKey(key: _sessionKey);

  @override
  Future<String?> accessToken() =>
      _secureStorage.read(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _secureStorage.write(
        key: _sessionKey,
        value: persistSessionString,
      );

  @override
  Future<void> removePersistedSession() =>
      _secureStorage.delete(key: _sessionKey);
}

/// Protects the short-lived PKCE verifier used by email callback flows.
class SecurePkceStorage extends GotrueAsyncStorage {
  const SecurePkceStorage();

  static const _keyPrefix = 'split_it.auth.pkce.';

  @override
  Future<String?> getItem({required String key}) =>
      _secureStorage.read(key: '$_keyPrefix$key');

  @override
  Future<void> setItem({required String key, required String value}) =>
      _secureStorage.write(key: '$_keyPrefix$key', value: value);

  @override
  Future<void> removeItem({required String key}) =>
      _secureStorage.delete(key: '$_keyPrefix$key');
}
