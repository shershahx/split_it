import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/app_user.dart';

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  AppUser? getCurrentUser() => _mapUser(_client.auth.currentUser);

  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final user = _mapUser(response.user);
    if (user == null) {
      throw const AuthException('Sign in did not return a user.');
    }
    return user;
  }

  /// Returns true when email confirmation is required before sign-in.
  Future<bool> registerWithEmailPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {'display_name': name.trim()},
      emailRedirectTo: 'com.splitit://auth-callback/',
    );
    return response.session == null;
  }

  Future<AppUser> updateDisplayName(String name) async {
    final response = await _client.auth.updateUser(
      UserAttributes(data: {'display_name': name.trim()}),
    );
    final user = _mapUser(response.user);
    if (user == null) {
      throw const AuthException('Profile update did not return a user.');
    }
    return user;
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
      redirectTo: 'com.splitit://auth-callback/',
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  AppUser? _mapUser(User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.id,
      email: user.email,
      displayName: user.userMetadata?['display_name'] as String?,
      photoUrl: user.userMetadata?['avatar_url'] as String?,
      provider: user.appMetadata['provider'] as String?,
    );
  }
}
