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
<<<<<<< HEAD
    final displayName = _validateDisplayName(name);
    final response = await _client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {'display_name': displayName},
=======
    final response = await _client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {'display_name': name.trim()},
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
      emailRedirectTo: 'com.splitit://auth-callback/',
    );
    return response.session == null;
  }

  Future<AppUser> updateDisplayName(String name) async {
<<<<<<< HEAD
    final displayName = _validateDisplayName(name);
    final previousUser = _client.auth.currentUser;
    if (previousUser == null) {
      throw const AuthException('Sign in before updating your name.');
    }
    // The schema's Auth metadata trigger synchronizes the public profile in
    // this same transaction; clients must not write to profiles directly.
    final response = await _client.auth.updateUser(
      UserAttributes(data: {'display_name': displayName}),
    );
    final user = _mapUser(response.user);
    if (user == null ||
        user.uid != previousUser.id ||
        user.displayName != displayName) {
      throw const AuthException(
          'Profile update did not return the expected user.');
=======
    final response = await _client.auth.updateUser(
      UserAttributes(data: {'display_name': name.trim()}),
    );
    final user = _mapUser(response.user);
    if (user == null) {
      throw const AuthException('Profile update did not return a user.');
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
    }
    return user;
  }

<<<<<<< HEAD
  String _validateDisplayName(String name) {
    final trimmed = name.trim();
    if (trimmed.runes.isEmpty || trimmed.runes.length > 80) {
      throw const AuthException(
          'Display name must be between 1 and 80 characters.');
    }
    return trimmed;
  }

  Future<void> signOut() => _client.auth.signOut();

=======
  Future<void> signOut() => _client.auth.signOut();

>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
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
