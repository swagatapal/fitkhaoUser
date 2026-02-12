/// Route names for navigation throughout the app
class RouteNames {
  RouteNames._();

  // Splash route
  static const String splash = '/';
  static const String onboarding = '/OnboardingScreen';

  // Auth routes
  static const String phoneAuth = '/phone-auth';
  static const String otpVerification = '/otp-verification';
  static const String nameInput = '/name-input';
  static const String addressInput = '/address-input';
  static const String mapPicker = '/map-picker';
  static const String bmiAnalysis = '/bmi-analysis';
  static const String healthScore = '/health-score';
  static const String detailedHealthInfo = '/detailed-health-info';

  // Main routes
  static const String home = '/home';
  static const String dashboard = '/dashboard';

  // Profile routes
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String editPersonalProfile = '/edit-personal-profile';
  static const String preferencesSaved = '/preferences-saved';
  static const String addresses = '/addresses';
  static const String addAddress = '/add-address';

  // Restaurant routes
  static const String restaurants = '/restaurants';
  static const String restaurantDetails = '/restaurant-details';
  static const String menu = '/menu';

  // Order routes
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orders = '/orders';
  static const String orderDetails = '/order-details';

  // Other routes
  static const String settings = '/settings';
  static const String help = '/help';
  static const String termsAndConditions = '/terms-and-conditions';
  static const String privacyPolicy = '/privacy-policy';
}
