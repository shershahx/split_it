// lib/features/auth/data/auth_service.dart
// Development version with stubs - Production will use HMS for AppGallery

import '../../../shared/models/app_user.dart';

class AuthService {
  // Get current user
  Future<AppUser?> getCurrentUser() async {
    // TODO: Implement Firebase Auth or HMS for production
    throw UnimplementedError('Authentication not implemented - ready for HMS integration');
  }

  // Sign in with email and password
  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    // TODO: Implement Firebase Auth or HMS for production
    throw UnimplementedError('Authentication not implemented - ready for HMS integration');
  }

  // Request email verification code (required before registration)
  Future<void> requestEmailVerifyCode(String email) async {
    // TODO: Implement Firebase Auth or HMS for production 
    throw UnimplementedError('Authentication not implemented - ready for HMS integration');
  }

  // Create user with email, password and verification code
  Future<AppUser> createUserWithEmailPassword({
    required String email,
    required String password,
    required String verifyCode,
  }) async {
    // TODO: Implement Firebase Auth or HMS for production
    throw UnimplementedError('Authentication not implemented - ready for HMS integration');
  }

  // Sign in with Huawei ID
  Future<AppUser> signInWithHuaweiId() async {
    // TODO: Implement HMS Huawei ID for production
    throw UnimplementedError('Huawei ID authentication requires HMS - use for AppGallery production');
  }

  // Update user display name
  Future<AppUser> updateDisplayName(String name) async {
    // TODO: Implement Firebase Auth or HMS for production
    throw UnimplementedError('Authentication not implemented - ready for HMS integration');
  }

  // Sign out
  Future<void> signOut() async {
    // TODO: Implement Firebase Auth or HMS for production
    throw UnimplementedError('Authentication not implemented - ready for HMS integration');
  }

  // Register with email, password and verification code
  Future<AppUser> registerWithEmailPassword({
    required String email,
    required String password,
    required String verifyCode,
    required String name,
  }) async {
    // TODO: Implement HMS for production
    throw UnimplementedError('Authentication not implemented - ready for HMS integration');
  }

  // Request password reset verification code
  Future<void> requestPasswordResetCode(String email) async {
    // TODO: Implement HMS for production
    throw UnimplementedError('Authentication not implemented - ready for HMS integration');
  }

  // Reset password with verification code
  Future<void> resetPassword({
    required String email,
    required String newPassword,
    required String verifyCode,
  }) async {
    // TODO: Implement HMS for production
    throw UnimplementedError('Authentication not implemented - ready for HMS integration');
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    // TODO: Implement Firebase Auth or HMS for production
    throw UnimplementedError('Authentication not implemented - ready for HMS integration');
  }
}