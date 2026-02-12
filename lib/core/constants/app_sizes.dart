/// Centralized dimensions and spacing constants for the entire app
/// All padding, margin, height, width, and other dimension values should reference this file
class AppSizes {
  AppSizes._();

  // ==================== SPACING SYSTEM ====================
  // Base spacing scale (following 4px grid system)
  static const double spacing2 = 2.0;
  static const double spacing4 = 4.0;
  static const double spacing6 = 6.0;
  static const double spacing8 = 8.0;
  static const double spacing10 = 10.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing28 = 28.0;
  static const double spacing30 = 30.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;
  static const double spacing42 = 42.0;
  static const double spacing48 = 48.0;
  static const double spacing60 = 60.0;
  static const double spacing70 = 70.0;
  static const double spacing80 = 80.0;
  static const double spacing90 = 90.0;

  // Padding & Margin (aliases for common usage)
  static const double p4 = spacing4;
  static const double p6 = spacing6;
  static const double p8 = spacing8;
  static const double p10 = spacing10;
  static const double p12 = spacing12;
  static const double p16 = spacing16;
  static const double p20 = spacing20;
  static const double p24 = spacing24;
  static const double p28 = spacing28;
  static const double p30 = spacing30;
  static const double p32 = spacing32;
  static const double p40 = spacing40;
  static const double p42 = spacing42;
  static const double p48 = spacing48;
  static const double p60 = spacing60;
  static const double p70 = spacing70;
  static const double p80 = spacing80;
  static const double p90 = spacing90;

  // ==================== BORDER RADIUS ====================
  static const double radius4 = 4.0;
  static const double radius6 = 6.0;
  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius15 = 15.0;
  static const double radius16 = 16.0;
  static const double radius20 = 20.0;
  static const double radius24 = 24.0;
  static const double radius32 = 32.0;
  static const double radius42 = 42.0;
  static const double radius50 = 50.0;

  // Border Radius aliases for semantic naming
  static const double radiusSmall = radius4;
  static const double radiusMedium = radius12;
  static const double radiusLarge = radius16;
  static const double radiusXLarge = radius24;
  static const double radiusRound = radius50;

  // ==================== ICON SIZES ====================
  static const double icon12 = 12.0;
  static const double icon14 = 14.0;
  static const double icon16 = 16.0;
  static const double icon18 = 18.0;
  static const double icon19 = 19.0;
  static const double icon20 = 20.0;
  static const double icon24 = 24.0;
  static const double icon28 = 28.0;
  static const double icon32 = 32.0;
  static const double icon48 = 48.0;
  static const double icon50 = 50.0;
  static const double icon60 = 60.0;
  static const double icon80 = 80.0;

  // Icon size aliases
  static const double iconXSmall = icon12;
  static const double iconSmall = icon16;
  static const double iconMedium = icon24;
  static const double iconLarge = icon32;
  static const double iconXLarge = icon48;
  static const double iconXXLarge = icon60;

  // ==================== BORDER WIDTHS ====================
  static const double borderThin = 0.5;
  static const double borderNormal = 1.0;
  static const double borderMedium = 1.5;
  static const double borderThick = 2.0;
  static const double borderExtraThick = 2.5;

  // ==================== BUTTON DIMENSIONS ====================
  static const double buttonHeightSmall = 40.0;
  static const double buttonHeightMedium = 48.0;
  static const double buttonHeightLarge = 56.0;
  static const double buttonHeight = 50.0; // Default button height

  // ==================== INPUT FIELD DIMENSIONS ====================
  static const double inputHeight = 56.0;
  static const double inputHeightSmall = 48.0;
  static const double inputHeightLarge = 60.0;

  // ==================== COMPONENT SPECIFIC SIZES ====================

  // Header/AppBar
  static const double headerHeight = 60.0;
  static const double appBarHeight = 56.0;

  // Profile Images
  static const double profileImageSmall = 48.0;
  static const double profileImageMedium = 90.0;
  static const double profileImageLarge = 121.0;
  static const double profileImageWidth = 121.0;
  static const double profileImageHeight = 90.0;

  // OTP Box
  static const double otpBoxSize = 60.0;
  static const double otpBoxSizeLarge = 70.0;

  // Divider
  static const double dividerWidth = 1.0;
  static const double dividerHeight = 25.0;
  static const double dividerHeightMedium = 30.0;

  // Score Card
  static const double scoreCardWidth = 181.0;
  static const double scoreCardHeight = 96.0;

  // Logo Sizes
  static const double logoWidth = 100.0;
  static const double logoHeight = 81.0;
  static const double logoWidthLarge = 200.0;
  static const double logoHeightLarge = 60.0;

  // Onboarding Image
  static const double onboardingImageWidth = 258.0;
  static const double onboardingImageHeight = 261.0;

  // Map Pin
  static const double mapPinSize = 50.0;
  static const double mapPinDotSize = 4.0;

  // Checkbox
  static const double checkboxSize = 20.0;

  // Container Heights
  static const double containerHeightSmall = 40.0;
  static const double containerHeightSmall70 = 70.0;
  static const double containerHeightMedium = 96.0;
  static const double containerHeightLarge = 150.0;
  static const double containerHeightXLarge = 250.0;
  static const double containerHeight381 = 381.0;

  // Container Widths
  static const double containerWidthSmall = 50.0;
  static const double containerWidthMedium = 181.0;
  static const double containerWidthLarge = 342.0;

  // Next Button (Onboarding)
  static const double nextButtonSize = 50.0;

  // Icon Container
  static const double iconContainerSize = 50.0;

  // ==================== ELEVATION / SHADOW ====================
  static const double elevation1 = 1.0;
  static const double elevation2 = 2.0;
  static const double elevation4 = 4.0;
  static const double elevation8 = 8.0;
  static const double elevation12 = 12.0;
  static const double elevation16 = 16.0;

  // Shadow Blur Radius
  static const double shadowBlur1 = 1.0;
  static const double shadowBlur10 = 10.0;
  static const double shadowBlur12 = 12.0;
  static const double shadowBlur20 = 20.0;
  static const double shadowBlur24 = 24.0;

  // Shadow Spread Radius
  static const double shadowSpread0 = 0.0;
  static const double shadowSpread2 = 2.0;

  // ==================== OPACITY VALUES ====================
  static const double opacity08 = 0.08;
  static const double opacity10 = 0.10;
  static const double opacity20 = 0.20;
  static const double opacity30 = 0.30;

  // ==================== ANIMATION / SCALE ====================
  static const double scaleSmall = 0.9;
  static const double scaleNormal = 1.0;
  static const double scaleLoading = 20.0;
  static const double scaleLoadingLarge = 24.0;
  static const double strokeWidth = 2.5;

  // ==================== SCREEN PADDING ====================
  static const double screenPaddingHorizontal = 20.0;
  static const double screenPaddingVertical = 20.0;
  static const double screenPaddingTop = 70.0;
  static const double screenPaddingBottom = 20.0;

  // ==================== MAX LENGTHS ====================
  static const int maxLengthPhone = 10;
  static const int maxLengthOTP = 6;
  static const int maxLengthPincode = 6;
  static const int maxLengthOTPDigit = 1;
  static const int maxLines1 = 1;
  static const int maxLines3 = 3;

  // ==================== DURATIONS (milliseconds) ====================
  static const int durationFast = 300;
  static const int durationMedium = 500;
  static const int durationSlow = 1000;
  static const int durationSuccess = 3000;

  // ==================== IMAGE QUALITY ====================
  static const int imageQuality = 85;
  static const int imageMaxWidth = 1024;
  static const int imageMaxHeight = 1024;
}
