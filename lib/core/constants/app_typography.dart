import 'package:flutter/material.dart';

/// App-wide typography constants for consistent text styling
class AppTypography {
  AppTypography._();

  /// Font family used throughout the app
  static const String fontFamily = 'Lato';

  /// Font weights
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;

  /// Base font sizes (using 4px scale)
  static const double fontSize10 = 10.0;
  static const double fontSize12 = 12.0;
  static const double fontSize13 = 13.0;
  static const double fontSize14 = 14.0;
  static const double fontSize15 = 15.0;
  static const double fontSize16 = 16.0;
  static const double fontSize18 = 18.0;
  static const double fontSize20 = 20.0;
  static const double fontSize22 = 22.0;
  static const double fontSize24 = 24.0;
  static const double fontSize28 = 28.0;
  static const double fontSize32 = 32.0;
  static const double fontSize36 = 36.0;
  static const double fontSize40 = 40.0;
  static const double fontSize60 = 60.0;

  // Aliases for common usage
  static const double fontSizeXS = fontSize12;
  static const double fontSizeSM = fontSize14;
  static const double fontSizeMD = fontSize16;
  static const double fontSizeLG = fontSize18;
  static const double fontSizeXL = fontSize20;
  static const double fontSize2XL = fontSize24;
  static const double fontSize3XL = fontSize28;
  static const double fontSize4XL = fontSize32;

  /// Line heights
  static const double lineHeightTight = 1.25;
  static const double lineHeightNormal = 1.5;
  static const double lineHeightRelaxed = 1.75;

  /// Letter spacing
  static const double letterSpacingTight = -0.5;
  static const double letterSpacingNormal = 0.0;
  static const double letterSpacingWide = 0.5;
}

/// Extension on BuildContext for easy access to typography with responsive sizing
extension TypographyExtension on BuildContext {
  /// Get responsive text style based on theme and screen size
  TextStyle getResponsiveTextStyle({
    required double fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: AppTypography.fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight ?? AppTypography.regular,
      color: color,
      letterSpacing: letterSpacing ?? AppTypography.letterSpacingNormal,
      height: height,
      decoration: decoration,
    );
  }
}
