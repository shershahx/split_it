// lib/shared/models/app_user.dart
import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? provider; // 'email', 'hwid'

  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.provider,
  });

  String get initials {
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!.substring(0, 1).toUpperCase();
    }
    if (email != null && email!.isNotEmpty) {
      return email!.substring(0, 1).toUpperCase();
    }
    return 'U';
  }

  @override
  List<Object?> get props => [uid, email, displayName, photoUrl, provider];
}