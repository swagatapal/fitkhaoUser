/// Application configuration
/// Control app behavior with feature flags
class AppConfig {
  AppConfig._();

  /// Show debug information in UI (for development)
  static const bool showDebugInfo = true;

  /// OTP Configuration
  static const int otpLength = 6;
  static const int otpResendTimerSeconds = 60;

  /// Valid OTP for verification
  /// Use "1234" to successfully verify OTP
  static const String mockValidOtp = '1234';

  /// App Version
  static const String appVersion = '1.0.0';

  /// App Name
  static const String appName = 'FitKhao';

  /// API
  static const String baseApiUrl = 'http://10.15.146.1:7071';
  static const String sendOtpPath = '/api/auth/send-otp';
  static const String verifyOtpPath = '/api/auth/verify-otp';
  static const String updateProfilePath = '/api/user/profile';
  static const String createSubscriptionPath = '/api/subscription/create';
  static const String walletTopupPath = '/api/wallet/topup';
  static const String placeOrderPath = '/api/orders/place';
  static const String walletOrderPaymentPath = '/api/wallet/order-payment';
  static const String orderHistoryPath = '/api/orders/history';
  static const String cancelOrderPath = '/api/orders/cancel';
  static const String walletTransactionsPath = '/api/wallet/transactions';

  /// Analytics base (trending)
  static const String analyticsBaseApiUrl = 'http://10.54.111.1:7071';
  static const String trendingPath = '/api/analytics/trending/';
}
