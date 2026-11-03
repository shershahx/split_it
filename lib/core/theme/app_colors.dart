import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Colors - Cobalt Blue (Trust, Finance)
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF5E92F3);
  static const Color primaryDark = Color(0xFF003C8F);

  // Secondary Colors - Vibrant Green (Positive/Success)
  static const Color secondary = Color(0xFF4CAF50);
  static const Color secondaryLight = Color(0xFF80E27E);
  static const Color secondaryDark = Color(0xFF087F23);

  // Semantic Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF29B6F6);

  // Balance Colors
  static const Color positiveBalance = Color(0xFF4CAF50); // You are owed
  static const Color negativeBalance = Color(0xFFE53935); // You owe
  static const Color neutralBalance = Color(0xFF9E9E9E);  // Settled

  // Light Theme Colors
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color dividerLight = Color(0xFFE5E7EB);

  // Dark Theme Colors
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  static const Color borderDark = Color(0xFF2D2D2D);
  static const Color dividerDark = Color(0xFF2D2D2D);

  // Category Colors
  static const Color categoryFood = Color(0xFFFF7043);
  static const Color categoryTransport = Color(0xFF42A5F5);
  static const Color categoryEntertainment = Color(0xFFAB47BC);
  static const Color categoryUtilities = Color(0xFF26A69A);
  static const Color categoryShopping = Color(0xFFEC407A);
  static const Color categoryRent = Color(0xFF5C6BC0);
  static const Color categoryTravel = Color(0xFFFFCA28);
  static const Color categoryHealth = Color(0xFFEF5350);
  static const Color categoryOther = Color(0xFF78909C);

  // Avatar Colors (for users without profile pictures)
  static const List<Color> avatarColors = [
    Color(0xFF26A69A),
    Color(0xFF42A5F5),
    Color(0xFFAB47BC),
    Color(0xFFFF7043),
    Color(0xFFEC407A),
    Color(0xFF5C6BC0),
    Color(0xFFFFCA28),
    Color(0xFF66BB6A),
  ];

  // Get avatar color based on name hash
  static Color getAvatarColor(String name) {
    if (name.isEmpty) return avatarColors[0];
    final hash = name.hashCode.abs();
    return avatarColors[hash % avatarColors.length];
  }

  // Gradient for splash/onboarding
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, secondaryLight],
  );
}
