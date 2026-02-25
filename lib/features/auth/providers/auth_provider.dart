// lib/features/auth/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/app_user.dart';
import '../data/auth_service.dart';

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Auth state - manually managed (AGConnect has no auth state stream)
final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<AppUser?>>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<AppUser?>> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AsyncValue.loading()) {
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    try {
      final user = await _authService.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e) {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    final user = await _authService.signInWithEmailPassword(
      email: email,
      password: password,
    );
    state = AsyncValue.data(user);
  }

  Future<void> requestVerifyCode(String email) async {
    await _authService.requestEmailVerifyCode(email);
  }

  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String verifyCode,
    required String name,
  }) async {
    final user = await _authService.registerWithEmailPassword(
      email: email,
      password: password,
      verifyCode: verifyCode,
      name: name,
    );
    state = AsyncValue.data(user);
  }

  Future<void> signInWithHuaweiId() async {
    final user = await _authService.signInWithHuaweiId();
    state = AsyncValue.data(user);
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> updateDisplayName(String name) async {
    final user = await _authService.updateDisplayName(name);
    state = AsyncValue.data(user);
  }

  Future<void> requestPasswordResetCode(String email) async {
    await _authService.requestPasswordResetCode(email);
  }

  Future<void> resetPassword({
    required String email,
    required String newPassword,
    required String verifyCode,
  }) async {
    await _authService.resetPassword(
      email: email,
      newPassword: newPassword,
      verifyCode: verifyCode,
    );
  }
}

// Convenience provider for current user
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).maybeWhen(
        data: (user) => user,
        orElse: () => null,
      );
});