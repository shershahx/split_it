// lib/features/auth/data/auth_service.dart
import 'package:agconnect_auth/agconnect_auth.dart';
import 'package:huawei_account/huawei_account.dart';

import '../../../shared/models/app_user.dart';

class AuthService {
  // Get current user
  Future<AppUser?> getCurrentUser() async {
    try {
      final user = await AGCAuth.instance.currentUser;
      return user != null ? _mapUser(user) : null;
    } catch (_) {
      return null;
    }
  }

  // Sign in with email and password
  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = EmailAuthProvider.credentialWithPassword(
        email.trim(),
        password,
      );
      final result = await AGCAuth.instance.signIn(credential);
      return _mapUser(result.user!);
    } on AGCAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Request email verification code (required before registration)
  Future<void> requestEmailVerifyCode(String email) async {
    try {
      final settings = VerifyCodeSettings(
        VerifyCodeAction.registerLogin,
        sendInterval: 30,
      );
      await EmailAuthProvider.requestVerifyCode(
        email.trim(),
        settings,
      );
    } on AGCAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Register with email, verification code, and password
  Future<AppUser> registerWithEmailPassword({
    required String email,
    required String password,
    required String verifyCode,
    required String name,
  }) async {
    try {
      final emailUser = EmailUser(
        email.trim(),
        verifyCode,
        password,
      );
      final result = await AGCAuth.instance.createEmailUser(emailUser);

      // Update display name
      final profileRequest = ProfileRequest(name.trim(), '');
      await result.user?.updateProfile(profileRequest);

      // Re-fetch user to get updated profile
      final updatedUser = await AGCAuth.instance.currentUser;
      return _mapUser(updatedUser ?? result.user!);
    } on AGCAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Huawei ID
  Future<AppUser> signInWithHuaweiId() async {
    try {
      // Step 1: Sign in with Huawei Account Kit
      final helper = AccountAuthParamsHelper()
        ..setAccessToken()
        ..setIdToken()
        ..setEmail()
        ..setProfile();

      final service = AccountAuthManager.getService(helper.createParams());
      final account = await service.signIn();

      // Step 2: Use the ID token to sign in to AGConnect Auth
      final credential = HuaweiAuthProvider.credentialWithToken(
        account.idToken!,
      );
      final result = await AGCAuth.instance.signIn(credential);
      return _mapUser(result.user!);
    } on AGCAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Huawei ID Sign-In failed: ${e.toString()}');
    }
  }

  // Update user display name
  Future<AppUser> updateDisplayName(String name) async {
    try {
      final user = await AGCAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      final profileRequest = ProfileRequest(name.trim(), '');
      await user.updateProfile(profileRequest);

      // Re-fetch to get updated profile
      final updatedUser = await AGCAuth.instance.currentUser;
      return _mapUser(updatedUser ?? user);
    } on AGCAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await AGCAuth.instance.signOut();
      // Also sign out from Huawei Account Kit
      try {
        final helper = AccountAuthParamsHelper();
        final service = AccountAuthManager.getService(helper.createParams());
        await service.signOut();
      } catch (_) {
        // Ignore if not signed in with Huawei ID
      }
    } catch (e) {
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  // Request password reset verification code
  Future<void> requestPasswordResetCode(String email) async {
    try {
      final settings = VerifyCodeSettings(
        VerifyCodeAction.resetPassword,
        sendInterval: 30,
      );
      await EmailAuthProvider.requestVerifyCode(
        email.trim(),
        settings,
      );
    } on AGCAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Reset password with verification code
  Future<void> resetPassword({
    required String email,
    required String newPassword,
    required String verifyCode,
  }) async {
    try {
      await AGCAuth.instance.resetPasswordWithEmail(
        email.trim(),
        newPassword,
        verifyCode,
      );
    } on AGCAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Map AGCUser to AppUser
  AppUser _mapUser(AGCUser user) {
    return AppUser(
      uid: user.uid ?? '',
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoUrl,
      provider: user.providerId == AuthProviderType.hms ? 'hwid' : 'email',
    );
  }

  // Handle AGConnect Auth exceptions
  String _handleAuthException(AGCAuthException e) {
    switch (e.code) {
      case 1: // AGCAuthExceptionCode.nullToken
        return 'Authentication token is null.';
      case 2: // AGCAuthExceptionCode.notSignIn
        return 'User is not signed in.';
      case 3: // AGCAuthExceptionCode.userLinked
        return 'This account is already linked.';
      case 4: // AGCAuthExceptionCode.userUnlinked
        return 'This account is not linked.';
      case 5: // AGCAuthExceptionCode.alreadySignInUser
        return 'A user is already signed in.';
      case 6: // AGCAuthExceptionCode.emailAlreadyInUse
        return 'An account already exists with this email.';
      case 7: // AGCAuthExceptionCode.passwordSame
        return 'New password must be different from old password.';
      case 8: // AGCAuthExceptionCode.passwordStrengthLow
        return 'Password is too weak. Use at least 6 characters.';
      case 9: // AGCAuthExceptionCode.invalidEmail
        return 'Please enter a valid email address.';
      case 10: // AGCAuthExceptionCode.userNotFound
        return 'No user found with this email.';
      case 11: // AGCAuthExceptionCode.verifyCodeError
        return 'Incorrect verification code.';
      case 12: // AGCAuthExceptionCode.passwordError
        return 'Incorrect password.';
      default:
        return 'Authentication error (code: ${e.code}). Please try again.';
    }
  }
}