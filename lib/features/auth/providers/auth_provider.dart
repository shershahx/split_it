import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/app_user.dart';
import '../data/auth_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(supabaseClientProvider)),
);

final passwordRecoveryProvider = StateProvider<bool>((ref) => false);

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<AppUser?>>((ref) {
<<<<<<< HEAD
  return AuthNotifier(
    ref.watch(authServiceProvider),
    onPasswordRecovery: () {
      ref.read(passwordRecoveryProvider.notifier).state = true;
    },
    onSignedOut: () {
      ref.read(passwordRecoveryProvider.notifier).state = false;
    },
  );
});

class AuthNotifier extends StateNotifier<AsyncValue<AppUser?>> {
  AuthNotifier(
    this._authService, {
    required void Function() onPasswordRecovery,
    void Function()? onSignedOut,
  }) : super(AsyncValue.data(_authService.getCurrentUser())) {
    _authSubscription = _authService.authStateChanges.listen((authState) {
      if (!mounted) return;
      if (authState.event == AuthChangeEvent.passwordRecovery) {
        onPasswordRecovery();
      } else if (authState.event == AuthChangeEvent.signedOut) {
        onSignedOut?.call();
=======
      return AuthNotifier(
        ref.read(authServiceProvider),
        onPasswordRecovery: () {
          ref.read(passwordRecoveryProvider.notifier).state = true;
        },
      );
    });

class AuthNotifier extends StateNotifier<AsyncValue<AppUser?>> {
  AuthNotifier(this._authService, {required void Function() onPasswordRecovery})
    : super(AsyncValue.data(_authService.getCurrentUser())) {
    _authSubscription = _authService.authStateChanges.listen((authState) {
      if (authState.event == AuthChangeEvent.passwordRecovery) {
        onPasswordRecovery();
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
      }
      state = AsyncValue.data(_authService.getCurrentUser());
    });
  }

  final AuthService _authService;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> signInWithEmail(String email, String password) async {
    final user = await _authService.signInWithEmailPassword(
      email: email,
      password: password,
    );
    state = AsyncValue.data(user);
  }

  Future<bool> registerWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    final requiresConfirmation = await _authService.registerWithEmailPassword(
      email: email,
      password: password,
      name: name,
    );
    state = AsyncValue.data(_authService.getCurrentUser());
    return requiresConfirmation;
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> updateDisplayName(String name) async {
    final user = await _authService.updateDisplayName(name);
    state = AsyncValue.data(user);
  }

  Future<void> sendPasswordResetEmail(String email) =>
      _authService.sendPasswordResetEmail(email);

  Future<void> updatePassword(String newPassword) =>
      _authService.updatePassword(newPassword);
}

// Convenience provider for current user
final currentUserProvider = Provider<AppUser?>((ref) {
<<<<<<< HEAD
  return ref.watch(authStateProvider).maybeWhen(
        data: (user) => user,
        orElse: () => null,
      );
=======
  return ref
      .watch(authStateProvider)
      .maybeWhen(data: (user) => user, orElse: () => null);
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
});
