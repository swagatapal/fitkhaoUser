import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Colors
  static const Color primaryGreen = Color(0xFF5D9E40);
  static const Color lightGreen = Color(0xFF9CCC9D);
  static const Color darkGreen = Color(0xFF4A7C4D);
  static const Color logoGreen = Color(0xFF5D9E40);
  static const Color logoLightGreen = Color(0xFF6BAD6D);
  static const Color disabledGreen = Color(0xFFA0D488);

  // Text Colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Background Colors
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundSecondary = Color(0xFFF5F5F5);

  // UI Element Colors
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color dividerColor = Color(0xFFE0E0E0);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF388E3C);
  static const Color warningColor = Color(0xFFF57C00);

  // Button Colors
  static const Color buttonPrimary = primaryGreen;
  static const Color buttonDisabled = disabledGreen;
  static const Color buttonTextPrimary = textWhite;
  static const Color buttonTextSecondary = textPrimary;

  // Input Field Colors
  static const Color inputBackground = Color(0xFFFFFFFF);
  static const Color inputBorder = borderColor;
  static const Color inputFocusedBorder = primaryGreen;
  static const Color inputHintText = textTertiary;
}
