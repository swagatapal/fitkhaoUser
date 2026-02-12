import 'package:flutter/material.dart';

/// Responsive utility class for handling different screen sizes
class ResponsiveUtils {
  ResponsiveUtils._();

  /// Screen size breakpoints
  static const double mobileSmall = 320; // iPhone SE, small Android
  static const double mobileMedium = 375; // iPhone 12/13/14
  static const double mobileLarge = 414; // iPhone 14 Plus, large Android
  static const double mobileXLarge = 430; // iPhone 14 Pro Max
  static const double tablet = 768;
  static const double desktop = 1024;

  /// Get screen width
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get screen height
  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Check if device is small mobile (< 360px)
  static bool isSmallMobile(BuildContext context) {
    return screenWidth(context) < 360;
  }

  /// Check if device is mobile
  static bool isMobile(BuildContext context) {
    return screenWidth(context) < tablet;
  }

  /// Check if device is tablet
  static bool isTablet(BuildContext context) {
    return screenWidth(context) >= tablet && screenWidth(context) < desktop;
  }

  /// Check if device is desktop
  static bool isDesktop(BuildContext context) {
    return screenWidth(context) >= desktop;
  }

  /// Get responsive width (percentage of screen width)
  static double widthPercent(BuildContext context, double percent) {
    return screenWidth(context) * (percent / 100);
  }

  /// Get responsive height (percentage of screen height)
  static double heightPercent(BuildContext context, double percent) {
    return screenHeight(context) * (percent / 100);
  }

  /// Get responsive font size based on screen width
  static double responsiveFontSize(BuildContext context, double size) {
    final width = screenWidth(context);

    if (width < mobileSmall) {
      return size * 0.85; // 15% smaller for very small devices
    } else if (width < mobileMedium) {
      return size * 0.9; // 10% smaller for small devices
    } else if (width > mobileXLarge) {
      return size * 1.1; // 10% larger for large devices
    }

    return size; // Default size for medium devices
  }

  /// Get responsive spacing based on screen width
  static double responsiveSpacing(BuildContext context, double spacing) {
    final width = screenWidth(context);

    if (width < mobileSmall) {
      return spacing * 0.8; // 20% smaller spacing
    } else if (width < mobileMedium) {
      return spacing * 0.9; // 10% smaller spacing
    } else if (width > mobileXLarge) {
      return spacing * 1.1; // 10% larger spacing
    }

    return spacing; // Default spacing
  }

  /// Get safe padding considering notches and system UI
  static EdgeInsets safeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Get horizontal padding based on screen width
  static double horizontalPadding(BuildContext context) {
    final width = screenWidth(context);

    if (width < mobileSmall) {
      return 16.0;
    } else if (width < mobileMedium) {
      return 20.0;
    } else if (width < mobileLarge) {
      return 24.0;
    } else if (width < tablet) {
      return 28.0;
    }

    return 32.0; // For tablets and larger
  }

  /// Get vertical padding based on screen height
  static double verticalPadding(BuildContext context) {
    final height = screenHeight(context);

    if (height < 667) {
      return 16.0; // Small devices (iPhone SE)
    } else if (height < 736) {
      return 20.0; // Medium devices
    } else if (height < 812) {
      return 24.0; // Standard devices
    }

    return 28.0; // Large devices
  }

  /// Calculate responsive size based on design base width (default: 375)
  static double responsive(BuildContext context, double size, {double baseWidth = 375}) {
    final width = screenWidth(context);
    return (size / baseWidth) * width;
  }

  /// Get appropriate logo size based on screen
  static double logoSize(BuildContext context) {
    final width = screenWidth(context);

    if (width < mobileSmall) {
      return 40.0;
    } else if (width < mobileMedium) {
      return 45.0;
    } else if (width < mobileLarge) {
      return 55.0;
    }

    return 70.0;
  }

  /// Get appropriate button height based on screen
  static double buttonHeight(BuildContext context) {
    final width = screenWidth(context);

    if (width < mobileSmall) {
      return 48.0;
    } else if (width < mobileMedium) {
      return 52.0;
    }

    return 56.0;
  }

  /// Get appropriate input field height based on screen
  static double inputHeight(BuildContext context) {
    final width = screenWidth(context);

    if (width < mobileSmall) {
      return 48.0;
    } else if (width < mobileMedium) {
      return 52.0;
    }

    return 56.0;
  }
}

/// Extension on BuildContext for easy access to responsive utilities
extension ResponsiveExtension on BuildContext {
  /// Get screen width
  double get screenWidth => ResponsiveUtils.screenWidth(this);

  /// Get screen height
  double get screenHeight => ResponsiveUtils.screenHeight(this);

  /// Check if small mobile
  bool get isSmallMobile => ResponsiveUtils.isSmallMobile(this);

  /// Check if mobile
  bool get isMobile => ResponsiveUtils.isMobile(this);

  /// Check if tablet
  bool get isTablet => ResponsiveUtils.isTablet(this);

  /// Check if desktop
  bool get isDesktop => ResponsiveUtils.isDesktop(this);

  /// Get responsive width percentage
  double widthPercent(double percent) => ResponsiveUtils.widthPercent(this, percent);

  /// Get responsive height percentage
  double heightPercent(double percent) => ResponsiveUtils.heightPercent(this, percent);

  /// Get responsive font size
  double responsiveFontSize(double size) => ResponsiveUtils.responsiveFontSize(this, size);

  /// Get responsive spacing
  double responsiveSpacing(double spacing) => ResponsiveUtils.responsiveSpacing(this, spacing);

  /// Get horizontal padding
  double get horizontalPadding => ResponsiveUtils.horizontalPadding(this);

  /// Get vertical padding
  double get verticalPadding => ResponsiveUtils.verticalPadding(this);

  /// Get logo size
  double get logoSize => ResponsiveUtils.logoSize(this);

  /// Get button height
  double get buttonHeight => ResponsiveUtils.buttonHeight(this);

  /// Get input height
  double get inputHeight => ResponsiveUtils.inputHeight(this);

  /// Calculate responsive size
  double responsive(double size, {double baseWidth = 375}) {
    return ResponsiveUtils.responsive(this, size, baseWidth: baseWidth);
  }
}
