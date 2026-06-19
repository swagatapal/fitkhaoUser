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
  //static const String baseApiUrl = 'http://10.15.146.1:7071';
  //static const String baseApiUrl = 'https://fitkhao-cbacb6hnb6b0dpab.centralindia-01.azurewebsites.net';

  // development url
  static const String baseApiUrl = 'https://fitkhaodev-dtambvcxh2c2c7f3.centralindia-01.azurewebsites.net';

  // production url
   //static const String baseApiUrl  = 'https://fitkhao-cbacb6hnb6b0dpab.centralindia-01.azurewebsites.net';



  static const String sendOtpPath = '/api/auth/send-otp';
  static const String verifyOtpPath = '/api/auth/verify-otp';
  static const String updateProfilePath = '/api/user/profile';

  /// Delivery addresses (user-managed)
  /// • list   → GET    deliveryAddressesPath
  /// • create → POST   deliveryAddressPath
  /// • update → PUT    deliveryAddressPath/{id}
  /// • delete → DELETE deliveryAddressPath/{id}
  static const String deliveryAddressPath = '/api/user/delivery-address';
  static const String deliveryAddressesPath = '/api/user/delivery-addresses';
  static const String createSubscriptionPath = '/api/subscription/create';
  static const String walletTopupPath = '/api/wallet/topup';
  static const String placeOrderPath = '/api/orders/place';
  static const String walletOrderPaymentPath = '/api/wallet/order-payment';
  static const String orderHistoryPath = '/api/orders/history';
  static const String orderInvoicePath = '/api/orders';
  static const String cancelOrderPath = '/api/orders/cancel';
  static const String walletTransactionsPath = '/api/wallet/transactions';
  static const String uploadImagePath = '/api/upload/image';

  /// Delivery Slots
  static const String deliverySlotListPath = '/api/delivery-slot/list';
  static const String deliverySlotConfirmPath = '/api/delivery-slots/confirm';
  static const String deliverySlotsPath = '/api/delivery-slots';

  /// Subscription plans (public)
  static const String subscriptionPlansPath = '/api/adm/subscription-plan';

  /// Pricing preview for a plan (auth). Query: planId, cancelAnytimeSelected.
  static const String subscriptionPricingPreviewPath =
      '/api/subscription/pricing-preview';

  /// Refund preview for an active subscription before cancelling (auth).
  static String subscriptionCancelPreviewPath(String subscriptionId) =>
      '/api/subscriptions/$subscriptionId/cancel-preview';

  /// Cancel an active subscription (auth).
  static String subscriptionCancelPath(String subscriptionId) =>
      '/api/subscriptions/$subscriptionId/cancel';

  /// Subscription invoice (auth).
  static String subscriptionInvoicePath(String subscriptionId) =>
      '/api/subscriptions/$subscriptionId/invoice';

  /// Subscription event history (auth).
  static String subscriptionHistoryPath(String subscriptionId) =>
      '/api/subscriptions/$subscriptionId/history';

  /// App content — terms & conditions, privacy policy (public)
  static const String appContentPath = '/api/app-content';
  static const String appConstant = '/api/app/constants';

  static const String appVersionPath = '/api/app-version';
  static const String eligibleCouponsPath = '/api/user/coupons';
  static const String razorpayCreateOrderPath = '/api/razorpay/create-order';
  static const String razorpayVerifyPaymentPath = '/api/razorpay/verify-payment';
  static const String notificationsPath = '/api/notifications';
  static const String userHistoryPath = '/api/user/history';
  static const String dishReviewPath = '/api/user/dish/review';

  /// Server-backed cart (GET fetch / POST upsert+remove).
  static const String cartPath = '/api/cart';

  /// Google Maps / Places API key (must have Maps SDK + Places API enabled)
  static const String googleMapsApiKey = 'AIzaSyDp2r7Do-Z-cwgxiYpE1yzZecBHFz0ocaw';


  /// Kitchen open/close status — append /{kitchenId}/open-status
  static const String kitchenOpenStatusPath = '/api/adm/kitchen';

  /// Dish categories (outlet-level)
  static const String outletDishCategoryPath = '/api/adm/outlet-dish-category';

  /// Dishes with optional category filter
  static const String outletDishPath = '/api/adm/outlet-dish';
  //static const outletDishPath = '/api/user/outlet-dish';

  /// Backend dish search (by query + kitchen)
  static const String outletDishSearchPath = '/api/adm/outlet-dishes/search';

  static const String exercisePath = '/api/adm/exercise';
  static const String physiologicalCategoriesPath = '/api/adm/physiological-category';
  static const String professionPath = '/api/adm/profession';

/// Analytics base (trending)
  //static const String trendingPath = '/api/analytics/trending/';
}
